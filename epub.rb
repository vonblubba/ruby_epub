require 'epub/parser'
require 'curses'
require 'psych'
require 'logger'

def init_app
  Curses.init_screen
  Curses.noecho
  Curses.cbreak
  Curses.curs_set(0)

  @save_file = './bookmark.yml'
  @filename = ARGV[0]

  @log = Logger.new('log.txt')

  @book = EPUB::Parser.parse(@filename)

  @win = Curses.stdscr
  @win.keypad = true
  @max_x = @win.maxx
  @max_y = @win.maxy
  @area = (@max_x) * (@max_y -5)
end

def set_header
  @win.setpos(0, 0)
  @win.addstr("#{@book.metadata.title} - Chapter #{@bookmark_cur_chap} of #{@parser.count}")
end

def page_down
  @bookmark_cur_pos += @area

  if @bookmark_cur_pos >= @chapter.content_document.nokogiri.text.length
    @chapter = @parser.next
    @bookmark_cur_chap += 1
    @bookmark_cur_pos = 0
  end

  @win.clear

  set_header

  @win.setpos(2, 0)
  @win.addstr(reformat_wrapped(@chapter.content_document.nokogiri.text[@bookmark_cur_pos..(@bookmark_cur_pos + @area)], @max_x - 1))
  @win.refresh
end

def page_up
  @bookmark_cur_pos -= @area

  if @bookmark_cur_pos < 0
    @parser.rewind
    @bookmark_cur_chap -= 1
    if @bookmark_cur_chap < 0
      @bookmark_cur_chap = 0
    end
    for i in 1..@bookmark_cur_chap
      @chapter = @parser.next
    end
    @bookmark_cur_pos = @chapter.content_document.nokogiri.text.length - @area
  end

  @win.clear

  set_header

  @win.setpos(2, 0)
  @win.addstr(reformat_wrapped(@chapter.content_document.nokogiri.text[@bookmark_cur_pos..(@bookmark_cur_pos + @area)], @max_x - 2))
  @win.refresh
end

def save_bookmark
  File.open('bookmark.yml', 'w') do |file|
    file.write(Psych.dump({ 'bookmark_chapter' => @bookmark_cur_chap, 'bookmark_char' => @bookmark_cur_pos }))
  end
end

def load_bookmark
  saves = Psych.load_file(@save_file)

  @bookmark_chapter = saves['bookmark_chapter']
  @bookmark_char = saves['bookmark_char']
  @bookmark_cur_pos = @bookmark_char
  @bookmark_cur_chap = @bookmark_chapter

  @parser = @book.each_page_on_spine

  for i in 1..@bookmark_chapter
    @chapter = @parser.next
  end

  set_header

  @win.setpos(2, 0)
  @win.addstr(reformat_wrapped(@chapter.content_document.nokogiri.text[@bookmark_cur_pos..(@bookmark_cur_pos + @area)], @max_x - 1))
  @win.refresh
end

def reformat_wrapped(s, width=78)

  lines = []
  line = ""
  s.gsub(".\n", '.#.# ').gsub("”\n", '”#c# ').gsub(/[\r\n\s+]{3,}/, '#p#').split(/\s+/).each do |word|
    if (word.include?("#.#") or word.include?("#c#") or word.include?("#r#") or word.include?("#p#"))
      splitted = word.split(/(#.#|#c#|#r#|#p#)/)
      line << " " << splitted[0]
      lines << line if line
      line = ""
      if splitted[1] == "#p#"
        line = "\n\n"
        lines << line
        line = ""
      end
      if splitted[2]
        line << " " << splitted[2]
      end
      if splitted[4]
        line << " " << splitted[4]
      end
    elsif line && line.size + word.size >= width
      lines << line
      line = word
    elsif line && line.empty?
      line = word
    else
      #@log.debug "step 3 line size: #{line.size}, word: #{word}"
      line << " " << word
    end
  end
  lines << line if line
  return lines.join "\n"
end

begin
  init_app

  load_bookmark

  while true
    @input = @win.getch

    if @input == 258
      page_down
    elsif @input == 259
      page_up
    elsif @input == "q" or @input == 27
      save_bookmark
      break
    end
  end
ensure
  Curses.close_screen
end