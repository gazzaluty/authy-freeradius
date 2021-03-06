package Authy::IDStores::CSV;

use 5.010;
use strict;
use warnings FATAL => 'all';

use Authy::ModuleUtil;
use Authy::Text;
use Carp qw(croak);
use Encode qw(encode);
use Parse::CSV;

our ($_FILE, $_SEPARATOR, $_QUOTE, $_ESCAPE_CHARACTER, $_USER_NAME_INDEX, $_ID_INDEX);

# Configuration option names:
use constant {
    _OPT_FILE                    => 'File',
    _OPT_SEPARATOR               => 'Separator',
    _OPT_QUOTE                   => 'Quote',
    _OPT_ESCAPE_CHARACTER        => 'EscapeCharacter',
    _OPT_USER_NAME_COLUMN_NUMBER => 'UserNameColumnNumber',
    _OPT_ID_COLUMN_NUMBER        => 'IDColumnNumber',
};

# Default configuration values:
use constant {
    _DEF_FILE                    => undef,
    _DEF_SEPARATOR               => ',',
    _DEF_QUOTE                   => '"',
    _DEF_ESCAPE_CHARACTER        => '"',
    _DEF_USER_NAME_COLUMN_NUMBER => undef,
    _DEF_ID_COLUMN_NUMBER        => undef,
};

sub initialize {
    my ($class, $config) = @_;

    # Load the configuration options.
    $_FILE = _get_value($config, _OPT_FILE, _DEF_FILE);
    $_SEPARATOR = _get_value($config, _OPT_SEPARATOR, _DEF_SEPARATOR);
    $_QUOTE = _get_value($config, _OPT_QUOTE, _DEF_QUOTE);
    $_ESCAPE_CHARACTER = _get_value($config, _OPT_ESCAPE_CHARACTER, _DEF_ESCAPE_CHARACTER);
    my $user_name_column_number = _get_value($config, _OPT_USER_NAME_COLUMN_NUMBER, _DEF_USER_NAME_COLUMN_NUMBER);
    my $id_column_number = _get_value($config, _OPT_ID_COLUMN_NUMBER, _DEF_ID_COLUMN_NUMBER);

    # Validate the configuration options.
    die "Flat file field separator must be eight bytes or less in length\n"
        if length(encode('UTF-8', $_SEPARATOR)) > 8;
    die "Flat file quote string must be eight bytes or less in length\n"
        if length(encode('UTF-8', $_QUOTE)) > 8;
    die "Flat file field separator and quote string must differ\n"
        if $_SEPARATOR eq $_QUOTE;
    die "Flat file escape char must be a single character\n"
        if length(encode('UTF-8', $_ESCAPE_CHARACTER)) > 1;
    die "Invalid flat file user name column number '$user_name_column_number'"
        unless $user_name_column_number =~ /^\d*$/;
    die "Flat file user name column number must be at least 1"
        unless int($user_name_column_number) >= 1;
    die "Invalid flat file user name column number '$id_column_number'"
        unless $id_column_number =~ /^\d*$/;
    die "Flat file user name column number must be at least 1"
        unless int($id_column_number) >= 1;

    $_USER_NAME_INDEX = int($user_name_column_number) - 1;
    $_ID_INDEX = int($id_column_number) - 1;
}

sub _get_value {
    my ($config, $option_name, $default_value, $required) = @_;
    $required = 1 unless defined $required;

    my $value = $config->{$option_name};
    if (!defined $value && defined $default_value) {
        log_info("No value specified for configuration setting 'ID Store/$option_name'; using the default value: '$default_value'");
        $value = $default_value;
    }
    if (defined $value) {
        $value =~ s/^\s+|\s+$//g;
    }
    if ((!defined $value || length($value) == 0) && $required) {
        die "No value specified for ID store configuration option '$option_name'\n";
    }
    return $value;
}

sub get_authy_id {
    my (undef, $user_name) = @_;

    # Create the flat file parser.
    my $id;
    open my $parser_fh, '<:encoding(UTF-8)', $_FILE or die "Cannot open flat file at $_FILE: $!";
    my $parser = Parse::CSV->new(
        handle   => $parser_fh,
        csv_attr => {
            binary      => 1,
            sep         => $_SEPARATOR,
            quote       => $_QUOTE,
            escape_char => $_ESCAPE_CHARACTER,
        },
    );

    # Search each entry for a matching user.
    my $lc_user_name = lc $user_name;
    while (my $entry = $parser->fetch()) {
        if ($lc_user_name eq lc $entry->[$_USER_NAME_INDEX]) {
            $id = $entry->[$_ID_INDEX];
            last;
        }
    }

    # Close the parser file handle.
    close $parser_fh or log_err("Unable to close flat file $_FILE: $!");

    # Return the ID if everything went well.
    return $id unless $parser->errstr;

    # Throw the resulting error.
    die sprintf("Failed to parse flat file: %s", $parser->errstr);
}

1;
