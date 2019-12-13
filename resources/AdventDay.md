N.B: This was posted for Day 15 of the 2019 Raku Advent Calendar on 15 Dec 2019.

# Santa had too much eggnog

We’re just over a week from Christmas and Santa is sending his elves the final present lists.
Unfortunately, Santa had a bit too much eggnog and so the list that he sent to his elves was …
not the greatest.  Take a look at some of it:

```
Johnny
 - 4 bsaeball gluvs
 - 2 batts
 - 2 ballz
Mary
 - 3 fancee dols
 - 1 dressss
 - 1 bbaskebtall
```

Santa somehow managed to keep a nice format that we could mostly process with regexen, so
the elves started hammering away at a nice grammar:

```
grammar Santa'sList {
  rule TOP        {       <kid's-list>+    }
  rule kid's-list {     <name>     <gift>+ }
  rule gift       { '-' <quantity> <item>  }
  token name      { <-[\n]>   }
  token quantity  { <.digit>+ }
  token item      { <.alpha>+ % \h+ }
}
```

While the elves figured that they *could* try to figure out what he meant in an action object,
they decided it would be more interesting to create a token that they could reuse not just
in the grammar, but in any random regex — these elves are crafty!

They wanted to make a new token that they'd call `<fuzzy>` that could somehow capture Santa's
drunken scribblings (can we call his typed list a scribbling?).  But regex syntax doesn't
actually allow for doing any kind of fuzzy matching.  But here Raku's engine comes to the
rescue.  So first they created a code block inside of the token.  Code blocks are normally
defined with just `{ 🦋 }` but because they needed to define the success of a match, they opted
instead of the `<?{ 🦋 }>` block, which will not only run the code, but will also fail if the
block returns a false-y value.

```
  token fuzzy {
    (<.alpha>+ % \h+)
    <?{
      # 🦋 code here
    }>
  }
```

Before they started writing their code, they did two other things.  First they named the
capture to be a bit easier to maintain down the road.  And secondly, they realized they
needed to actually get the list of possible toys into the token somehow.  So they
added a signature to the token to pass it in.

```
  token fuzzy(**@toys) {
    $<santa's-text>=(<.alpha>+ % \h+)
    <?{
      # 🦋 code here
    }>
  }
```

Now they could begin the code itself.  They would take Santa’s text, and compare it to
each of the possible toys, and decide which one was the closest match:

```
  token fuzzy(**@toys) {
    $<santa's-text>=(<.alpha>+ % \h+)
    <?{
      my $best = @toys
                   .map({ $^toy, qgram($toy,$<santa's-text>.Str)})
                   .sort( *.tail )
                   .tail;
      say "Santa meant to write {$best[0]}";
    }>
  }
```

The Q-gram function they used creates N-grams for each word, and compares them to see
how many they have in common.  With testing they found that the best value for N (the
length of each substring) was about half the average length.  The way that Raku works,
writing the Q-gram function was super easy:

```
  #| Generate space-padded N-grams of length n for string t.
  sub ngrams = -> \t, \n {
    my \s = (' ' x n - 1)  ~ t ~  (' ' x n - 1);
    do for ^(t.chars + n) { s.substr: $_, n }
  }

  #| Calculate Q-gram score using bag operations
  sub qgram (\a, \b) {
    my \q  = (a.chars + b.chars) div 4;
    my \aₙ = ngrams(a,q).BagHash;
    my \bₙ = ngrams(b,q).BagHash;

    (aₙ ∩ bₙ) / (aₙ ∪ bₙ)      # Coefficient de communauté de Joccard
  }
```

Raku let the elves calculate N-grams in just two clean lines of code, and then use
those to calculate the Joccard-index between the two strings in just four more easy
to read lines of code.

Putting this back into their grammar, they ended up with the following:

```
grammar Santa'sList {
  rule TOP        {       <kid's-list>+    }
  rule kid's-list {     <name>     <gift>+ }
  rule gift       { '-' <quantity> <item>  }
  token name      { <-[\n]>   }
  token quantity  { <.digit>+ }
  token item      { <fuzzy(@gifts)> }
  token fuzzy     { … }
  sub ngrams      { … }
  sub qgrams      { … }
}
```

That's a pretty handy format, but an important problem remains.  How do they get access
to the best matched text?  If they were to match and request, say, `$<kid's-list>[0]<gift>[0]<item>`
they would only get Santa's original illegible mess.  They could do an action but that
requires doing a parse with actions, which means the fuzzy token is tied to the vagaries of
grammar parsing.  Works fine here, but… less reusable.

But elves are good at packing and wrapping.  They decide to make a package that wraps
the fuzzy token so that both Santa's original and the corrected version are easily accessible
in a DWIM manner.  This ‘package’ can't be declared with `package` or `module`, though, because
the wrapping process requires using the special sub `EXPORT`.  Their basic process looks like
the following:

```
sub EXPORT {
  # Make the fuzzy token in the elve's factory
  my token fuzzy (*@words) { … } 

  # Wrap it in wrapping paper (apply a role) so it's prettier (easier to use)
  &fuzzy.wrap( … )

  # Ship out (export) the wrapped version
  %( '&fuzzy' => &fuzzy )
}
```

Any other special tools the elves need can be included in the `EXPORT` block, for example,
the Q- and N-gram functions.  So how will they actually do the wrapping?  First, they
design the paper, that is, a `role` that will override the `.Str` to give the clean/corrected
value, but also provide access to a `.fuzz` function to allow access to older values:

```
  role Fuzzy[$clear,$fuzz] {
    method Str  { $clear }
    method fuzz { $fuzz  }
  }
```

Now, the wrapped function could look something like the following:

```
  &fuzzy.wrap(
    sub (|) {
      my $match = callsame;

      # Failed match evals to false, and is just passed along
      # Successful match gets Fuzzy role mixed in.
      $match
        ?? $match but Fuzzy[$match.??, $match.??]
        !! $match
    }
  );
```

There's a small problem.  The results of the calculations they ran inside of the token
aren't available.  One solution they thought of involved adding new parameters to
to the `fuzzy` token with the trait `is raw` so that the values could be passed back,
but that felt like something the old C++ elves would do.  No, Santa's Raku elves had a
better idea: dynamic variables.  They made two of them, and refactored the original
fuzzy method to assign to them:

```
  my token fuzzy(**@toys) {
    $<santa's-text>=(<.alpha>+ % \h+)
    <?{
      my $best = @toys
                  .map({ $^toy, qgram($toy,$<santa's-text>.Str)})
                  .sort( *.tail )
                  .tail;
      $*clear = $best[0];
      $*fuzz  = ~$<santa's-text>;
    }>
  }

  &fuzzy.wrap(
    sub (|) {
      my $*fuzz;
      my $*clear;

      my $match = callsame;   # sets $match to result of the original

      $match
        ?? $match but Fuzzy[$*clear, $*fuzz]
        !! $match
    }
  );
```

They did a test with some values and all went well, until an item wasn't found:

```
"I like the Norht Pole" ~~ /I like the $<dir>=<fuzzy: <North South> Pole>/;
say $<dir>.clear;   # --> "North"
say $<dir>.fuzz;    # --> "Norht"

"I like the East Pole" ~~ /I like the $<dir>=<fuzzy: <North South> Pole>/;
say $<dir>.clear;   # --> "North"
say $<dir>.fuzz;    # --> "East"
```

What happened?  The elves realized that their token was matching no matter what.
This is because the `<?{ 🦋 }` block will only fail if it returns a false-y
value.  The last statement, being an assignment of a string, will virtually
always be truthy.  To fix this, they added a simple conditional to the end of
the block to fail if the Q-gram score wasn't sufficiently high.

```
  my token fuzzy(**@toys) {
    $<santa's-text>=(<.alpha>+ % \h+)
    <?{
      my $best = @toys
                   .map({ $^toy, qgram($toy,$<santa's-text>.Str)})
                   .sort( *.tail )
                   .tail;

      $*clear = $best[0];
      $*fuzz  = ~$<santa's-text>;

      # Arbitrary but effective score cut off.
      $best[1] > 0.33
    }>
  }
```

With that, they were done, and able to process Santa's horrible typing.

Of course, there were a lot of improvements that the elves could still make to
make their fuzzy token more useful.  After they had made use of it (and taken
the eggnog away from Santa so they wouldn't need it), they polished it up
so that it could bring joy to everyone.

---

With that, I can also announce the release of Regex::FuzzyToken.  To use it,
just do like the elves and in a grammar or any other code, say `use Regex::FuzzyToken`
and the token `fuzzy` will be imported into your current scope.  It has a few
extra features, so take a look at its readme for information on some of its options.

While not everyone will use or have need of a `FuzzyToken`, I hope that this
shows off some interesting possibilities when creating tokens that might be
better defined programmatically.  For example, the CLDR includes a Rule-base
number format (RBNF) that, if implemented in a similar way into a token,
could match the number "three" (or also "3") that would being `three` in
string contexts, but `3` in a number context.