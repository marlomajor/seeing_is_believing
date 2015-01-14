@xmpfilter
Feature: Xmpfilter style
  Support the same (or highly similar) interface as xmpfilter,
  so that people who use that lib can easily transition to SiB.

  Scenario: --xmpfilter-style Generic updating of marked lines
    Given the file "magic_comments.rb":
    """
    1+1# =>
    2+2    # => 10
    "a
     b" # =>
    /a
     b/ # =>
    1
    "omg"
    # =>
    "omg2"
    # => "not omg2"
    3+3#=>
    """
    When I run "seeing_is_believing --xmpfilter-style magic_comments.rb"
    Then stderr is empty
    And the exit status is 0
    And stdout is:
    """
    1+1# => 2
    2+2    # => 4
    "a
     b" # => "a\n b"
    /a
     b/ # => /a\n b/
    1
    "omg"
    # => "omg"
    "omg2"
    # => "omg2"
    3+3# => 6
    """


  Scenario: --xmpfilter-style uses pp to inspect annotations whose value comes from the previous line (#44)
    Given the file "xmpfilter-prev-line1.rb":
    """
    { foo: 42,
      bar: {
        baz: 1,
        buz: 2,
        fuz: 3,
      },
      wibble: {
        magic_word: "xyzzy",
      }
    } # =>
    # =>
    """
    When I run "seeing_is_believing --xmpfilter-style xmpfilter-prev-line1.rb"
    Then stdout is:
    """
    { foo: 42,
      bar: {
        baz: 1,
        buz: 2,
        fuz: 3,
      },
      wibble: {
        magic_word: "xyzzy",
      }
    } # => {:foo=>42, :bar=>{:baz=>1, :buz=>2, :fuz=>3}, :wibble=>{:magic_word=>"xyzzy"}}
    # => {:foo=>42,
    #     :bar=>{:baz=>1, :buz=>2, :fuz=>3},
    #     :wibble=>{:magic_word=>"xyzzy"}}
    """

  Scenario: --xmpfilter-style overrides previous multiline results
    Given the file "xmpfilter-prev-line2.rb":
    """
    {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
    # =>
    """
    When I run "seeing_is_believing --xmpfilter-style xmpfilter-prev-line2.rb | seeing_is_believing --xmpfilter-style"
    Then stdout is:
    """
    {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
    # => {:foo=>42,
    #     :bar=>{:baz=>1, :buz=>2, :fuz=>3},
    #     :wibble=>{:magic_word=>"xyzzy"}}
    """


  Scenario: --xmpfilter-style respects the line formatting (but not currently alignment strategies, it just preserves submitted alignment)
    Given the file "xmpfilter_line_lengths.rb":
    """
    '1' * 30 # =>
    # =>
    """
    When I run "seeing_is_believing --xmpfilter-style --line-length 19 xmpfilter_line_lengths.rb"
    Then stdout is:
    """
    '1' * 30 # => "1...
    # => "1111111111...
    """


  Scenario: Errors on annotated lines
    Given the file "xmpfilter_error_on_annotated_line.rb":
    """
    raise "ZOMG\n!!!!" # =>
    """
    When I run "seeing_is_believing --xmpfilter-style xmpfilter_error_on_annotated_line.rb"
    Then stderr is empty
    And the exit status is 1
    Then stdout is:
    """
    raise "ZOMG\n!!!!" # => RuntimeError: ZOMG\n!!!!

    # ~> RuntimeError
    # ~> ZOMG
    # ~> !!!!
    # ~>
    # ~> xmpfilter_error_on_annotated_line.rb:1:in `<main>'
    """


  Scenario: Errors on unannotated lines
    Given the file "xmpfilter_error_on_unannotated_line.rb":
    """
    raise "ZOMG\n!!!!"
    """
    When I run "seeing_is_believing --xmpfilter-style xmpfilter_error_on_unannotated_line.rb"
    Then stderr is empty
    And the exit status is 1
    Then stdout is:
    """
    raise "ZOMG\n!!!!" # ~> RuntimeError: ZOMG\n!!!!

    # ~> RuntimeError
    # ~> ZOMG
    # ~> !!!!
    # ~>
    # ~> xmpfilter_error_on_unannotated_line.rb:1:in `<main>'
    """


  Scenario: Cleaning previous output does not clean the xmpfilter annotations
    Given the file "xmpfilter_cleaning.rb":
    """
    # commented out # => previous annotation
    1 # => "1...
    # => "1111111111...
    #    "1111111111...
    # normal comment

    {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
    # => {:foo=>42,
    #     :bar=>{:baz=>1, :buz=>2, :fuz=>3},
    #     :wibble=>{:magic_word=>"xyzzy"}}
    """
    When I run "seeing_is_believing --xmpfilter-style --clean xmpfilter_cleaning.rb"
    Then stdout is:
    """
    # commented out # => previous annotation
    1 # =>
    # =>
    # normal comment

    {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
    # =>
    """


  # this one needs a bit more thought put into it, but I'm kinda fading now
  @not-implemented
  Scenario: Error raised on an annotated line does not wipe it out
    Given the file "error_on_annotated_line.rb":
    """
    a # =>
    # =>
    """
    When I run "seeing_is_believing --xmpfilter-style error_on_annotated_line.rb"
    Then stdout is:
    """
    idk, but we need to be able to fix the thing and run it again
    without losing the annotation
    """


  # maybe can't fix this as it depends on the implementation of PP.pp
  @not-implemented
  Scenario: It can record values even when method is overridden
    Given the file "pretty_inspect_with_method_overridden.rb":
    """
    def method()end; self # =>
    # =>
    """
    When I run "seeing_is_believing --xmpfilter-style pretty_inspect_with_method_overridden.rb"
    Then stdout is:
    """
    def method()end; self # => main
    # => main
    """


  @not-implemented
  Scenario: Multiline output that is repeatedly invoked
    Given the file "mutltiline_output_repeatedly_invoked.rb":
    """
    3.times do
      {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
      # =>
    end
    """
    When I run "seeing_is_believing --xmpfilter-style mutltiline_output_repeatedly_invoked.rb"
    Then stdout is:
    """
    Not sure what I want, but this is what xmpfilter does:

    3.times do
      {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
      # => {:foo=>42,
      #     :bar=>{:baz=>1, :buz=>2, :fuz=>3},
      #     :wibble=>{:magic_word=>"xyzzy"}}
      #    , {:foo=>42,
      #     :bar=>{:baz=>1, :buz=>2, :fuz=>3},
      #     :wibble=>{:magic_word=>"xyzzy"}}
      #    , {:foo=>42,
      #     :bar=>{:baz=>1, :buz=>2, :fuz=>3},
      #     :wibble=>{:magic_word=>"xyzzy"}}
    end
    """

  # Not sure how to handle this. Here are some ideas:
  # * Store info within the file that we can use to identify tehse lines.
  #   ie add a comment at the top of the file like "# SiB: remove 383282, 382321"
  #   where these numbers are like the hashes of the the comments we added or something.
  # * Mark successive lines with an annotation of their own
  # * Store the info somewhere else like a tempfile (seems harder, b/c now the data is disociated from the file,
  #   given that I usually run this unsaved, how would SiB figure out that these two were the same?)
  # * In this one case (first line is outdented), annotate differently, like prepend pipes to the annotations or something.
  @not-implemented
  Scenario: Multiline values where the first line is indented more than the successive lines
    Given the file "inspect_tree.rb":
    """
    bst = Object.new
    def bst.inspect
      "   4   \n"\
      " 2   6 \n"\
      "1 3 5 7\n"
    end
    bst
    # =>
    """
    When I run "seeing_is_believing --xmpfilter-style inspect_tree.rb"
    Then stdout is:
    """
    bst = Object.new
    def bst.inspect
      "   4\n"\
      " 2   6\n"\
      "1 3 5 7\n"
    end
    bst
    # =>    4
    #     2   6
    #    1 3 5 7
    """
    When I run


  Scenario: Xmpfilter uses the same comment formatting as normal
    Given the file "xmpfilter_result_lengths.rb":
    """
    $stdout.puts "a"*100
    $stderr.puts "a"*100

                 "a"    # =>
                 "aa"   # =>
                 "aaa"  # =>
                 "aaaa" # =>

    {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
    # =>

    raise "a"*100
    """
    When I run "seeing_is_believing -x --result-length 10 xmpfilter_result_lengths.rb"
    Then stderr is empty
    And stdout is:
    """
    $stdout.puts "a"*100
    $stderr.puts "a"*100

                 "a"    # => "a"
                 "aa"   # => "aa"
                 "aaa"  # => "aaa"
                 "aaaa" # => "a...

    {foo: 42, bar: {baz: 1, buz: 2, fuz: 3}, wibble: {magic_word: "xyzzy"}}
    # => {:...
    #     :...
    #     :...

    raise "a"*100 # ~> Ru...

    # >> aa...

    # !> aa...

    # ~> Ru...
    # ~> aa...
    # ~>
    # ~> xm...
    """
