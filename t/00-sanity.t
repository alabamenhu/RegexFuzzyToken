use Test;

grammar Foo {
  use Regex::FuzzyToken;

  token TOP { <fuzzy: <apple banana>> }
}

done-testing;
