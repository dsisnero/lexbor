require "../../src/lexbor"

str = if filename = ARGV[0]?
        File.read(filename, "UTF-8", invalid: :skip)
      else
        <<-HTML
        <body>
          <div>
            <hr/>
            left <a class=Lba> middle </a> <span> right <span> </span>
          </div>

          <noindex></noindex>
         </body>
        HTML
      end

N        = (ARGV[1]? || 10).to_i
TEST     = (ARGV[2]? || 0).to_i
COUNT    = (ARGV[3]? == "1")
WS       = ((ARGV[4]? || "1") == "1")
COL_SIZE = (ARGV[5]? || 1000).to_i

class Doc < Lexbor::Tokenizer::State
  getter counter

  def initialize(@counting = false)
    @counter = 0
  end

  def on_token(t)
    @counter += 1 if @counting && t.tag_id == Lexbor::Lib::TagIdT::LXB_TAG_A && !t.closed?
  end
end

case TEST
when 0
  puts "pure myhtml"
  t = Time.now
  s = 0
  N.times do
    parser = Lexbor::Parser.new(str)
    count = COUNT ? parser.nodes(:a).size : 0
    s += count
    parser.free
  end
  p s
  p Time.now - t
when 1
  puts "pure tokenizer"
  t = Time.now
  s = 0
  N.times do
    doc = Doc.new(COUNT).parse(str, WS)
    s += doc.counter
    doc.free
  end
  p s
  p Time.now - t
else
  puts "unknown test"
end
