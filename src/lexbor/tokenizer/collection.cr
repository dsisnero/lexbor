require "./token"

# Helper tokenizer state class which store tokens into array,
#   provide methods to iterator throuht them.
class Lexbor::Tokenizer::Collection < Lexbor::Tokenizer::State
  getter tokens, last_id

  @tkz : Lexbor::Lib::HtmlTokenizerT = Pointer(Void).null.as(Lexbor::Lib::HtmlTokenizerT)

  def parse(str, ws = true)
    super(str, ws)
  end

  def initialize
    @tokens = [] of Lexbor::Lib::HtmlToken
    @last_id = 0
  end

  def on_token(token)
    @tokens << token.raw_token
  end

  def clear
    @tokens = [] of Lexbor::Lib::HtmlToken
    @last_id = 0
  end

  def size
    @tokens.size
  end

  def on_begin(tok)
    @tkz = tok.tkz
  end

  def on_end
    @last_id = size - 1
  end

  @[AlwaysInline]
  def unsafe_token(i)
    Lexbor::Tokenizer::Token.new(self, (@tokens.to_unsafe + i).value)
  end

  @[AlwaysInline]
  protected def unsafe_token_pos(i)
    TokenPos.new(self, unsafe_token(i), i)
  end

  def root
    raise Lexbor::EmptyNodeError.new("empty collection") if size == 0
    TokenPos.new(self, unsafe_token(@last_id), -1)
  end

  def first
    raise Lexbor::EmptyNodeError.new("empty collection") if size == 0
    TokenPos.new(self, unsafe_token(0), 0)
  end

  def last
    raise Lexbor::EmptyNodeError.new("empty collection") if size == 0
    TokenPos.new(self, unsafe_token(@last_id), @last_id)
  end

  record TokenPos, collection : Collection, token : Lexbor::Tokenizer::Token, idx : Int32 do
    forward_missing_to @token

    def next
      if @idx < @collection.last_id
        @collection.unsafe_token_pos(@idx + 1)
      end
    end

    def prev
      if @idx > 0
        @collection.unsafe_token_pos(@idx - 1)
      end
    end

    def right
      RightIterator.new(self)
    end

    def left
      LeftIterator.new(self)
    end

    def scope
      ScopeIterator.new(self)
    end
  end

  def inspect(io)
    io << "Lexbor::Tokenizer::Collection(0x"
    io << object_id.to_s(16)
    io << ", tokens: "
    io << @tokens.size
    io << ')'
  end

  module Filter
    def text_nodes
      self.select { |t| t.tag_id == Lexbor::Lib::TagIdT::LXB_TAG__TEXT }
    end

    def nodes(tag_id : Lexbor::Lib::TagIdT, opened = true)
      self.select { |t| t.tag_id == tag_id && opened != t.closed? }
    end

    def nodes(tag_sym : Symbol, opened = true)
      nodes(Utils::TagConverter.sym_to_id(tag_sym), opened)
    end

    def nodes(tag_str : String, opened = true)
      nodes(Utils::TagConverter.string_to_id(tag_str), opened)
    end
  end

  struct RightIterator
    include ::Iterator(TokenPos)
    include Lexbor::Tokenizer::Collection::Filter

    @start_node : TokenPos
    @current_node : TokenPos? = nil

    def initialize(@start_node)
      rewind
    end

    def next
      @current_node = @current_node.not_nil!.next
      @current_node || stop
    end

    def rewind
      @current_node = @start_node
    end
  end

  struct LeftIterator
    include ::Iterator(TokenPos)
    include Lexbor::Tokenizer::Collection::Filter

    @start_node : TokenPos
    @current_node : TokenPos? = nil

    def initialize(@start_node)
      rewind
    end

    def next
      cn = @current_node = @current_node.not_nil!.prev
      case cn
      when nil
        stop
      else
        cn
      end
    end

    def rewind
      @current_node = @start_node
    end
  end

  class ScopeIterator
    include ::Iterator(TokenPos)
    include Lexbor::Tokenizer::Collection::Filter

    @start_node : TokenPos
    getter current_node : TokenPos
    @stop_tag_id : Lexbor::Lib::TagIdT

    def initialize(@start_node)
      @current_node = @start_node
      @stop_tag_id = @start_node.tag_id
    end

    def next
      nxt = @current_node.next
      if nxt && !((nxt.tag_id == @stop_tag_id) && nxt.closed?)
        @current_node = nxt
      else
        @current_node = nxt if nxt
        stop
      end
    end

    def rewind
      @current_node = @start_node
      @stop_tag_id = @start_node.tag_id
    end
  end
end
