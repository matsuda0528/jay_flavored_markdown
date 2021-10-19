# frozen_string_literal: true

#
#--
# Copyright (C) 2016 Nomura Laboratory
#
# This file is NOT part of kramdown and is licensed under the MIT.
#++
#

require "kramdown/parser"
require "kramdown/converter"
require "kramdown/utils"

# block 間の明示的な改行は， :blank エレメントとしてパーズされる
# span 中の改行は， :text エレメント中に残り，かつ，:br が挟まる
#
# + :blank は，そのまま反映する
# + span 中の改行と :br は全て削る
# + block の後には改行を1つ入れるが，block がネストしている場合は，改行が続くので，1つに集約する
#
# block は，通常インデントする必要はない．
# :root, :blank, :p, :header, :hr, :table, :tr, :td
#
# 以下のブロックは，インデントをする
# :blockquote, :codeblock
#
# :ul, :ol，:li, :dl  はインデントする
#
# dt (term), dd (definition)
#
# li は，中のブロック
# <ul> や <p> のように 実体のない (transparent) ブロックは，何もしない
# <li> のように，ぶら下げるブロックはインデントしない

module Kramdown
  module Converter
    # Converts a Kramdown::Document to ASCII Plain Text.
    #
    # You can customize this converter by sub-classing it and overriding the +convert_NAME+
    # methods. Each such method takes the following parameters:
    #
    # [+el+] The element of type +NAME+ to be converted.
    #
    # [+indent+] A number representing the current amount of spaces for indent (only used for
    #            block-level elements).
    #
    # The return value of such a method has to be a string containing the element +el+ formatted as
    # HTML element.
    class Ascii < Base
      MAX_COLUMN = 80

      include ::Kramdown::Utils::Html
      include ::Kramdown::Parser::Html::Constants

      # The amount of indentation used when nesting HTML tags.
      attr_accessor :indent

      # Initialize the ASCII converter with the given Kramdown document +doc+.
      def initialize(root, options)
        super
        @indent = 2
        @stack = []
        @xref_table = {}
        ref_visitor = ReferenceVisitor.new
        @root = ref_visitor.traverse(@root)
        @xref_table = ref_visitor.xref_table
        @item_table = ref_visitor.item_table
        @section_table = ref_visitor.section_table
        debug_dump_tree(@root) if $JAY_DEBUG
      end

      # Dispatch the conversion of the element +el+ to a +convert_TYPE+ method using the +type+ of
      # the element.
      def convert(elem, indent = 0)
        send(DISPATCHER[elem.type], elem, indent)
      end

      # The mapping of element type to conversion method.
      DISPATCHER = Hash.new { |h, k| h[k] = "convert_#{k}" }

      ################################################################
      private

      # Format the given element as span text.
      def format_as_span(name, _attr, body)
        return "<SPAN:#{name}>#{body}</SPAN:#{name}>" if $JAY_DEBUG

        body.to_s.gsub(/\n */, "")
      end

      # indent を付加した span の列を作る
      # 前提として span 内には block はない
      # span は，行頭にある (block に直接内包される)か，改行を含むものしか indent されないので注意すること．
      def render_span(elem, indent)
        elem.children.each do |child|
          body << send(DISPATCHER[child.type], child, indent)
        end
        # XXX
      end

      # Format the given element as block text.
      # current_indent は自身のインデント幅で，ブロック内の
      #
      # render_block: block エレメントをレンダリングする．
      #
      # 前提: span の子供には span しか入っていない (block は，来ない)
      # span の子供が block になるような記述ができるのか不明 (tree をチェックして waring を出すほうがいいかも)
      #
      # 自分(block) について，子供に span があったら，つなげて indent する
      #
      # DISPATCHER を通して作った str は，indent だけのインデントを持つブロックを返すという前提
      # str = send(DISPATCHER[inner_el.type], inner_el, indent)
      def render_block(elem, current_indent, add_indent = 0, bullet = nil)
        body = ""
        span = ""

        orig_indent = current_indent
        current_indent = [(add_indent + current_indent), 0].max

        elem.children.each do |inner_el|
          str = send(DISPATCHER[inner_el.type], inner_el, current_indent)

          if elem.ancestor?(:blockquote)
            body << str # no wrap
          elsif Element.category(inner_el) == :span
            span << str
          else
            # body << wrap_block(span, current_indent, 60) if span.length > 0
            body << span
            body << str
            span = ""
          end
        end
        if span.length.positive?
          # body << wrap_block(span, current_indent, 60)
          body << span
          span = ""
        end

        body = add_bullet_to_block(bullet, body, orig_indent) if bullet
        body = add_indent_to_block(add_indent, body) if add_indent.positive?
        # body = remove_indent(body, 2) if bullet && bullet.length > 2 && ancestor?(el, :li)
        body = "#{body.sub(/\s*\Z/, "")}\n"

        return "<BLOCK:#{elem.type}>#{body}</BLOCK:#{elem.type}>\n" if $JAY_DEBUG

        body.to_s
      end

      # XXX この中で span に indent を付けるのはおかしい
      #
      def wrap_block(body, indent, max_columns)
        # puts "WRAP_BLOCK: #{body}, #{indent}"
        body = remove_indent(body, indent)
        body = wrap(body, max_columns - indent)
        add_indent_to_block(indent, body)
        # puts "WRAPed_BLOCK: #{body}, #{indent}"
      end

      def remove_indent(body, indent)
        body.gsub(/^#{" " * indent}/, "")
      end

      def wrap(body, width)
        body = body.gsub(/[\r\n]/, "")
        string = ""
        length = 0
        body.each_char.map do |c|
          string << c
          length += (c.bytesize == 1 ? 1 : 2)
          if length > width
            string << "\n"
            length = 0
          end
        end
        string
      end

      ################################################################
      # conver each element

      def convert_blank(elem, indent)
        render_block(elem, indent)
      end

      def convert_text(elem, _indent)
        format_as_span("text", nil, elem.value)
      end

      def convert_p(elem, indent)
        render_block(elem, indent)
      end

      def convert_codeblock(elem, _indent)
        "-----------------------\n#{elem.value}-----------------------\n"
      end

      def convert_blockquote(elem, indent)
        "-----------------------\n#{render_block(elem, indent, 4)}-----------------------"
      end

      def convert_header(elem, indent)
        render_block(elem, indent, 0, elem.value.full_mark.to_s)
      end

      def convert_hr(_elem, _indent)
        "-" * MAX_COLUMN
      end

      def convert_ul(elem, indent)
        render_block(elem, indent)
      end

      def convert_dl(elem, indent)
        format_as_block("dl", nil, render_block(elem, indent), indent)
      end

      def convert_li(elem, indent)
        output = ""

        bullet = elem.value ? "(#{elem.value.mark})" : "*"

        output << "<BLOCK:li>" if $JAY_DEBUG
        output << render_block(elem, indent, 0, bullet)
        output << "</BLOCK:li>" if $JAY_DEBUG
        output
      end

      def add_bullet_to_block(bullet, body, indent)
        hang = 0
        bullet_offset = " " * (bullet.size + 1)
        indent_string = " " * indent
        hang_string   = " " * hang

        body = body.sub(/^#{indent_string}/, "#{indent_string}#{bullet} ")
        body = body.gsub(/\n/, "\n#{bullet_offset}")
        body = body.gsub(/^#{hang_string}/, "") if hang.positive?
        body
      end

      def add_indent_to_block(indent, body)
        spc = " " * indent
        body = "#{spc}#{body}".gsub(/\n/, "\n#{spc}")
      end

      def convert_dt(elem, indent)
        render_block(elem, indent)
      end

      def convert_html_element(_elem, _indent)
        ""
      end

      def convert_xml_comment(_elem, _indent)
        ""
      end

      def convert_table(elem, indent)
        render_block(elem, indent)
      end

      def convert_td(elem, indent)
        render_block(elem, indent)
      end

      def convert_comment(elem, indent)
        render_block(elem, indent)
      end

      def convert_br(_elem, _indent)
        "\n" # "\n"
      end

      def convert_a(elem, _indent)
        if (c = elem.children.first) && c.type == :text && c.value
          "[#{c.value}]"
        else
          elem.attr["href"].to_s
        end
      end

      def convert_img(elem, _indent)
        elem.attr["href"].to_s
      end

      def convert_codespan(elem, _indent)
        "-----------------------\n#{elem.value}-----------------------"
      end

      def convert_footnote(_elem, _indent)
        ""
      end

      def convert_raw(elem, _indent)
        elem.value + (elem.options[:category] == :block ? "\n" : "")
      end

      def convert_em(elem, indent)
        format_as_span(elem.type, elem.attr, render_block(elem, indent))
      end

      # ;gt
      def convert_entity(elem, indent)
        format_as_span(elem.type, elem.attr, render_block(elem, indent))
      end

      def convert_typographic_sym(elem, _indent)
        {
          mdash: "---",
          ndash: "--",
          hellip: "...",
          laquo_space: "<<",
          raquo_space: ">>",
          laquo: "<< ",
          raquo: " >>"
        }[elem.value]
      end

      def convert_smart_quote(elem, _indent)
        {
          lsquo: "'",
          rsquo: "'",
          ldquo: '"',
          rdquo: '"'
        }[elem.value]
      end

      def convert_math(elem, indent)
        format_as_span(elem.type, elem.attr, render_block(elem, indent))
      end

      def convert_abbreviation(elem, _indent)
        title = @root.options[:abbrev_defs][elem.value]
        attr = @root.options[:abbrev_attr][elem.value].dup
        attr["title"] = title unless title.empty?
        format_as_span("abbr", attr, elem.value)
      end

      def convert_root(elem, indent)
        render_block(elem, indent)
      end

      alias convert_ol convert_ul
      alias convert_dd convert_li
      alias convert_xml_pi convert_xml_comment
      alias convert_thead convert_table
      alias convert_tbody convert_table
      alias convert_tfoot convert_table
      alias convert_tr convert_table
      alias convert_strong convert_em

      ################################################################

      def convert_ref(elem, _indent)
        return "(#{@xref_table[elem.value].full_mark})" if @xref_table[elem.value]

        if elem.value =~ /^(\++|-+)$/
          parent = elem.find_first_ancestor(:header) || elem.find_first_ancestor(:li)
          table = parent.type == :li ? @item_table : @section_table
          rel_pos = (Regexp.last_match(1).include?("+") ? 1 : -1) * Regexp.last_match(1).length
          idx = parent.options[:relative_position] + rel_pos
          ref_el = idx >= 0 ? table[idx] : nil
          return "(#{ref_el.value.full_mark})" if ref_el
        end

        "(???)"
      end

      def convert_label(_elem, _indent)
        ""
      end

      def convert_action_item(elem, _indent)
        "-->(#{elem.options[:assignee]})"
      end

      def convert_issue_link(elem, _indent)
        elem.options[:match]
      end

      def debug_dump_tree(tree, indent = 0)
        $stderr.print " " * indent
        $stderr.print "#{tree.type}(#{Element.category(tree)}) <<#{tree.value.to_s.gsub("\n", '\n')}>>\n"
        tree.children.each do |c|
          debug_dump_tree(c, indent + 2)
        end
      end
    end
  end
end
