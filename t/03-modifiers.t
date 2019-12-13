use Test;

grammar A {
  use Regex::FuzzyToken;
  token TOP { $<a> = <fuzzy: <aaa ééé iii>, /<.alpha>+/, :i> }
}

is A.parse("AAA")<a>.Str, "aaa";
is A.parse("ÉÉÉ")<a>.Str, "ééé";

grammar B {
  use Regex::FuzzyToken;
  token TOP { $<b> = <fuzzy: <aaa ééé iii>, /<.alpha>+/, :m> }
}

is B.parse("áàä")<b>.Str, "aaa";
is B.parse("eẽê")<b>.Str, "ééé";

grammar C {
  use Regex::FuzzyToken;
  token TOP { $<c> = <fuzzy: <aaa ééé iii>, /<.alpha>+/, :i, :m> }
}

is C.parse("ÃÀÂ")<c>.Str, "aaa";
is C.parse("ÈÊE")<c>.Str, "ééé";

done-testing;
