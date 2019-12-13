#unit module FuzzyToken;

sub EXPORT {

  #| Used only for providing the original text and
  #| overriding the Str method.
  role Fuzzy[$match,$fuzz] {
    method fuzz { $fuzz  }
    method Str  { $match }
  }

  # The ideal value for Q is half the average length.
  # This ensures that no unequal string can return a value
  # of 1 (perfect match), possible with lower values like 2.
  sub qgram (\a, \b, \q = (a.chars + b.chars) div 4 ) {
    my &ngrams = -> \t, \n {
      my \s = ~ (' ' x n - 1)    # spaces pad the result, but
              ~ t                # the character used ideally
              ~ (' ' x n - 1);   # should not be in string
      do for ^(t.chars + n) { s.substr: $_, n }
    }
    my \aₙ = &ngrams(a,q).BagHash;
    my \bₙ = &ngrams(b,q).BagHash;

    # Wow, Raku makes this easy.  This is the Coefficient de communauté de Joccard
    # See https://en.wikipedia.org/wiki/Jaccard_index
    (aₙ ∩ bₙ) / (aₙ ∪ bₙ)
  }


  # These are quick methods to adjust text more
  # or less along regex modifier principles
  my &i  = method ($i) {$i ?? self.fc !! self}
  my &m  = method ($i) {$i ?? self.samemark(' ') !! self}
  my &ws = method ($i) {$i ?? self !! self.words.join }
  my &p  = method ($i) {$i ?? self !! self.split(/<:P>/).join }


  my token fuzzy(*@words, :$i = False, :$m = False, :$ws = True, :$q = 33) {

    # Variadics don't allow trailing parameters in signatures, but
    # that's easy enough to account for.  The default capture is
    # word characters, but that will ignore spaces, for instance.
    :my $capture;
      { $capture = (@words.tail ~~ Regex) ?? @words.pop !! /\w+/ }

    $<subject>=$capture

    # By using a pass/fail block, we just return false if
    # none of the candidates are acceptable matches.
    <?{

      die "The fuzzy token must have at least one candidate (capture is optional) \n"
              ~ "Usage: <fuzzy: 'optA', 'optB', 'optC', ..., /capture/> \n"
              ~ "   or: <fuzzy: @options, /capture/> "
      unless @words > 0;

      # Results are in the format [$candidate, $score],
      # and sorted by $score

      my $subject  = $<subject>.Str.&i($i).&m($m).&ws($ws);

      my @results = @words
                      .map({
                          $^word,
                          qgram
                              $^word.&i($i).&m($m).&ws($ws),
                              $subject
                      })
                      .sort( *.tail );

      # These values are used in the wrapping function
      # in the event of a successful match
      $*fuzz  = $<subject>.Str;
      $*clear = @results.tail[0];

      # Test if score is greater than the threshold.
      # Multiply by one hundred because :33q makes more sense
      # than :0.33q in my opinion.  A successful test results
      # in the captured text being consumed.  Otherwise, false
      # value causes the token match to fail.
      @results.tail[1] * 100 >= $q;
    }>
  }


  &fuzzy.wrap(
    sub (|) {
      my $*fuzz;  #  Dynamic allow for communication with the method
      my $*clear; #  (since we can't control its return, of course)

      my $match = callsame;

      # Failed match evals to false, and is just passed along
      # Successful match gets Fuzzy role mixed in.
      $match
        ?? $match but Fuzzy[$*clear,$*fuzz]
        !! $match
    }
  );

  # Export the fuzzy token in its wrapped form
  %( '&fuzzy' => &fuzzy )

}