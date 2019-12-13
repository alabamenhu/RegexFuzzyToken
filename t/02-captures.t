use Test;

grammar A {
  use Regex::FuzzyToken;
  token TOP { $<a> = <fuzzy: <aaa bbb ccc>, /<.alpha>+/> <.digit>+ }
}

is A.parse("aab323892")<a>.Str, "aaa";
is A.parse("cbc2443")<a>.Str, "ccc";

grammar B {
  use Regex::FuzzyToken;
  token TOP { $<b> = <fuzzy: <111 222 333>, /<.digit>+/> <.alpha>+ }
}

is B.parse("211aaa")<b>.Str, "111";
is B.parse("223bbb")<b>.Str, "222";

done-testing;
