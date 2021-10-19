# frozen_string_literal: true

require "test_helper"

class JayFlavoredMarkdownTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::JayFlavoredMarkdown::VERSION
  end

  # 行頭に１つのスペースを含む項番なしリストのネストの入力が，ネストではない項番なしリストの出力になる問題を検証するテスト
  def test_that_it_should_get_nesting_of_unordered_list
    assert_equal JayFlavoredMarkdownToPlainTextConverter.new("* aaa\n * aaa").content, "* aaa\n    * aaa"
  end

  # 文字列の下行の '-' の入力が，2段階見出しの出力になる問題を検証するテスト
  def test_that_it_should_get_hyphen_below_string
    assert_equal JayFlavoredMarkdownToPlainTextConverter.new("aaa\n-").content, "aaa\n-"
  end

  # 項番付きリストの下行の項番なしリストの入力が，項番付きリストの出力になる問題を検証するテスト
  def test_that_it_should_get_unordered_list_below_ordered_list
    assert_equal JayFlavoredMarkdownToPlainTextConverter.new("+ aaa\n* aaa").content, "(1) aaa\n* aaa"
  end

  # 項番なしリストの下行の項番付きリストの入力が，項番なしリストの出力になる問題を検証するテスト
  def test_that_it_should_get_ordered_list_below_unordered_list
    assert_equal JayFlavoredMarkdownToPlainTextConverter.new("* aaa\n+ aaa").content, "* aaa\n(1) aaa"
  end
end
