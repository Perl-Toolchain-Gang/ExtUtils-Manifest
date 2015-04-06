use strict;
use warnings;

use lib 't/lib';
use ManifestTest qw( catch_warning canon_warning spew runtemp );
use ExtUtils::Manifest qw( maniadd );
use Config;
use Test::More tests => 7;

my $LAST_ERROR;

# Return 1 if it fatalled, undef otherwise.
# Its almost bash!
# !fatal = expect not fatal.
# fatal  = expect fatal
sub fatal(&) {
  my ($code) = @_;
  my ($ok);
  {
    local $@;
    $ok = eval { $code->(); 1 };
    $LAST_ERROR = $@;
  }
  return !$ok;
}

runtemp "maniadd.unneeded_readonly" => sub {
  note "Ensuring maniadd does not need to write to a file for existing entries";

  spew( "MANIFEST", "foo #bar\n" );
SKIP: {
    chmod( 0400, "MANIFEST" );

    if ( -w "MANIFEST" or $Config{osname} eq "cygwin" ) {
      skip "Cant make manifest readonly", 5;
    }

    ok( !fatal { maniadd( { "foo" => "bar" } ) }, "maniadd() wont die adding an existing key" )
      or diag $LAST_ERROR;

    ok( !-w "MANIFEST", "MANIFEST is still readonly" );

    ok( fatal { maniadd( { "grrrwoof" => "yippie" } ) }, "maniadd will die adding a new key" )
      or diag $LAST_ERROR;

    like( $LAST_ERROR, qr/^\Qmaniadd() could not open MANIFEST:\E/, "maniadd dies with the expected warning" );

    ok( !-w "MANIFEST", "MANIFEST is still readonly" );

    chmod( 0600, 'MANIFEST' );
  }

};

runtemp "maniadd.unneeded_readonly_notrailingeol" => sub {
  note "Ensuring maniadd does not arbitrarily make a file writeable if it lacks an EOL";
  local $TODO = "Broken, GH #13";
  spew( "MANIFEST", "foo #bar" );
SKIP: {
    chmod( 0400, "MANIFEST" );

    if ( -w "MANIFEST" or $Config{osname} eq "cygwin" ) {
      skip "Cant make manifest readonly", 5;
    }
    ok( !fatal { maniadd( { "foo" => "bar" } ) }, "maniadd() wont die adding an existing key" )
      or diag $LAST_ERROR;

    ok( !-w "MANIFEST", "MANIFEST is still readonly" );

    chmod( 0600, "MANIFEST" );

  }

};

