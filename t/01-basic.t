use Test;

grammar Foo {
  use Regex::FuzzyToken;

  my @names = <Dasher Dancer Prancer Vixen Comet Cupid Dunder Blixem Rudolph>;
  token TOP {
    "The leader is "
    $<reindeer> = <fuzzy: @names>
  }
}

is Foo.parse("The leader is Dsher"  )<reindeer>.Str,  'Dasher';
is Foo.parse("The leader is Dsher"  )<reindeer>.fuzz, 'Dsher';
is Foo.parse("The leader is Lancer" )<reindeer>.Str,  'Dancer';
is Foo.parse("The leader is Lancer" )<reindeer>.fuzz, 'Lancer';
is Foo.parse("The leader is Pranc"  )<reindeer>.Str,  'Prancer';
is Foo.parse("The leader is rancr"  )<reindeer>.fuzz, 'rancr';
is Foo.parse("The leader is vxen"   )<reindeer>.Str,  'Vixen';
is Foo.parse("The leader is vxen"   )<reindeer>.fuzz, 'vxen';
is Foo.parse("The leader is Comt"   )<reindeer>.Str,  'Comet';
is Foo.parse("The leader is Comt"   )<reindeer>.fuzz, 'Comt';
is Foo.parse("The leader is Coopid" )<reindeer>.Str,  'Cupid';
is Foo.parse("The leader is Coopid" )<reindeer>.fuzz, 'Coopid';
is Foo.parse("The leader is Dunder" )<reindeer>.Str,  'Dunder';
is Foo.parse("The leader is Dunder" )<reindeer>.fuzz, 'Dunder';
is Foo.parse("The leader is Bliksem")<reindeer>.Str,  'Blixem';
is Foo.parse("The leader is Bliksem")<reindeer>.fuzz, 'Bliksem';
is Foo.parse("The leader is Rdulph" )<reindeer>.Str,  'Rudolph';
is Foo.parse("The leader is Rdulph" )<reindeer>.fuzz, 'Rdulph';

done-testing;
