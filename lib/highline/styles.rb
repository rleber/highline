#!/usr/local/bin/ruby -w

# highline.rb
#
#  Created by Richard LeBer on 2011-06-27.
#  Copyright 2005 Rebel Productions. All rights reserved.
#
# See HighLine for documentation.
#
# This is Free Software.  See LICENSE and COPYING for details.

# TODO HSB colors and conversion, see e.g. http://delphi.about.com/od/adptips2006/qt/RgbToHsb.htm

class HighLine
  
  def Style(from)
    case from
    when Style
      from
    when StyleElement, Color, Symbol, String
      Style([from])
    when Array
      Style.new(from)
    end
  end
  
  def StyleElement(from)
    case from
    when StyleElement
      from
    when Style
      raise "Can't create StyleElement from #{from.inspect}" unless from.size == 1
      from.first
    when Array, String, Symbol
      StyleElement.new(from)
    else
      raise "Don't know how to make a StyleElement from #{from.inspect}"
    end
  end
  
  def Color(from)
    case from
    when Color
      from
    when StyleElement
      from.color
    when Style
      Color(from.first)
    else
      Color.new(from)
    end
  end
  
  class StyleElement
    
    PREDEFINED_STYLES = {
      :clear       =>  "\e[0m",
      :reset       =>  "\e[0m", # Synonym for :clear
      :bold        =>  "\e[1m", # Note: Bold + a color gives you a bold color,
                                # e.g. bold black. Bold with no color gives you 
                                # the system-defined "bold" color. (For example,
                                # this defaults to bold red on a Mac running iTerm.)
      :dark        =>  "\e[2m",
      :underline   =>  "\e[4m",
      :underscore  =>  "\e[4m", # Synonym for :underline
      :blink       =>  "\e[5m",
      :reverse     =>  "\e[7m",
      :concealed   =>  "\e[8m",
    }
    PREDEFINED_STYLE_NAMES = PREDEFINED_STYLES.keys
    COLOR_TYPES = [:color, :on]
    OTHER_TYPES = [:scheme]
    ALLOWED_TYPES = PREDEFINED_STYLE_NAMES + COLOR_TYPES + OTHER_TYPES
    
    def self.valid_style_type?(style)
      ALLOWED_TYPES.include?([style].flatten.first)
    end

    def valid?(style)
      style_array = [style].flatten
      style_array.is_a?(Array) &&
      (0..1).include?(style_array.size) &&
      valid_style_type?(style_array) &&
      (!color?(style_array) || valid_color?(style_array)) &&
      (!scheme?(style_array) || valid_scheme?(style_array))
    end
    
    def self.style?(style)
      PREDEFINED_STYLES[[style].flatten.first]
    end
    
    def self.foreground?(style)
      [style].flatten.first == :color
    end
    
    def self.background?(style)
      [style].flatten.first == :on
    end
    
    def self.color?(style)
      foreground?(style) || background?(style)
    end
    
    def self.foreground(style)
      style_array = [style].flatten
      foreground?(style_array) ? style_array[1] : nil
    end
    
    def self.color(style)
      foreground(style)
    end
    
    def self.background(style)
      style_array = [style].flatten
      background?(style_array) ? style_array[1] : nil
    end
    
    def self.on(style)
      background(style)
    end
    
    def self.scheme?(style)
      [style].flatten.first == :scheme
    end
    
    def self.valid_color?(style)
      style_array = [style].flatten
      color = style_array[1]
      color?(style_array) && color.is_a?(Color) && color.valid?
    end
    
    def self.valid_scheme?(style)
      style_array = [style].flatten
      scheme?(style_array) && style_array.size==2
    end
    
    def self.style_definitions
      PREDEFINED_STYLES
    end
    
    def self.styles
      PREDEFINED_STYLE_NAMES
    end
    
    def self.rgb(*args)
      Color.rgb(*args)
    end
    
    def self.on_rgb(*args)
      StyleElement([:on, Color.rgb(*args)])
    end
    
    attr_reader :style
    
    def initialize(from=[])
      replace(from)
    end
    
    def style_type
      @style.first
    end
    
    def color
      @style[1]
    end
    alias_method :scheme, :color
    
    def valid?
      self.class.valid?(@style)
    end
    
    def check!
      raise "#{self.inspect} is not a valid StyleElement" unless valid?
    end
    
    def foreground?
      self.class_foreground?(style)
    end
    
    def background?
      self.class_background?(style)
    end
    
    def color?
      self.class.color?(style)
    end
    
    def foreground
      self.class.foreground(style)
    end
    alias_method :color, :foreground
    
    def background
      self.class.background(style)
    end
    alias_method :on, :background
    
    def valid_color?
      self.class.valid_color?(@style)
    end
    
    def valid_scheme?
      self.class.valid_scheme?(@style)
    end
    
    def style?
      self.class.style?(@style)
    end
    
    def replace(from)
      case from
      when String
        from = from.strip
        if from =~ /^\d{6}$/
          replace('rgb_'+from)
        else
          replace(from.to_sym)
        end
      when Symbol
        case from.to_s
        when /^rgb_(\d{6})$/
          replace [:color, Color.rgb($1)]
        when /^on_rgb_(\d{6})$/
          replace [:on, Color.rgb($1)]
        when /^on_(.*)/
          replace [:on, Color.new($1.to_sym)]
        else
          if PREDEFINED_STYLE_NAMES.include?(from)
            replace [from]
          elsif Color.predefined?(from)
            replace [:color, Color.new(from)]
          else
            replace [:scheme, from]
          end
        end
      when Array
        @style = from
        check!
      else
        @style = StyleElement(from).style.dup
      end
    end
    
    def code
      case style_type
      when :color
        color.code
      when :on
        Color.adjust_code(color.code,10)
      when :scheme
        Style(HighLine.color_scheme[scheme]).code
      else
        PREDEFINED_STYLES[style_type]
      end
    end
    
    # TODO This recurs; common base class, or Mixin?
    def encode(string)
      code + string + Color(:clear).code
    end
    
    def to_sym
      to_s.to_sym
    end
    
    def to_s
      case style_type
      when :color
        color.to_s
      when :on
        'on_' + color.to_s
      when :scheme
        scheme.to_s
      else
        style_type.to_s
      end
    end
    
    def inspect
      @style.inspect
    end
  end
  
  class Color
    BASIC_COLORS = {
      :black    =>  "\e[30m",
      :red      =>  "\e[31m",
      :green    =>  "\e[32m",
      :yellow   =>  "\e[33m",
      :blue     =>  "\e[34m",
      :magenta  =>  "\e[35m",
      :cyan     =>  "\e[36m",
      :white    =>  "\e[37m",
      :gray     =>  "\e[37m", # Synonym for :white
      :none     =>  "\e[38m",
    }
    BASIC_COLOR_NAMES = BASIC_COLORS.keys
    PREDEFINED_COLOR_NAMES = BASIC_COLOR_NAMES + BASIC_COLOR_NAMES.map{|color| ('bright_'+color.to_s).to_sym}
    
    def self.predefined?(color)
      PREDEFINED_COLOR_NAMES.include?(color)
    end
    
    def self.valid?(color)
      predefined?(color) || color.to_s =~ /^rgb_\d{6}$/
    end
    
    def self.rgb?(color)
      !predefined?(color)
    end
    
    def self.basic_colors
      BASIC_COLOR_NAMES
    end
    
    def self.colors
      PREDEFINED_COLOR_NAMES
    end
    
    def self.basic_color_definitions
      BASIC_COLORS
    end
    
    def self.adjust_code(code, adjustment)
      raise "Unexpected color code for #{color.inspect}" unless ccode =~ /(\e\[)(\d+)((?:;\d+)*m)$/
      $1 + ($2.to_i + adjustment).to_s + $3
    end
    
    attr_reader :color
    
    def initialize(from)
      replace(from)
    end
    
    def predefined?
      self.class.predefined?(@color)
    end
    
    def bright?
      !rgb? && color.to_s=~/^bright_/
    end
    
    def normal?
      !rgb? && !bright?
    end
    
    def base_color
      return nil if rgb?
      color.to_s.sub(/^bright_/,'')
    end
    
    def valid?
      self.class.valid?(color)
    end
    
    def rgb?
      self.class.rgb?(color)
    end
    
    def check!
      raise "#{self.inspect} is not a valid color" unless valid?
    end
    
    def replace(from)
      case from
      when String
        @color = from.to_sym
      when Symbol
        @color = from
      when Color
        @color = from.color
      when Array # Treat as RGB
        self.class.rgb(from)
      else
        raise "Cannot create a color from #{from}"
      end
    end
    
    def self.rgb(*colors)
      colors = colors.flatten
      color_string = ''
      colors.each do |color|
        if color.is_a?(Numeric)
          color = color.round
          raise "Color values not in the range 0..255: #{colors.inspect}" unless (0..255).include(color)
          color_string += '%02x' % color
        else
          color_string += color.to_s
        end
      end
      raise "RGB color #{colors.inspect} does not generate 6 hex digits" unless color_string.size==6
      Color.new(('rgb_' + color_string).to_sym)
    end
    
    def code
      if rgb?
        raise "Bad RGB code in #{self.inspect}" unless color.to_s =~ /^(on_)?rgb_([a-fA-F0-9]{6})$/
        on = $1
        rgb = $2.scan(/../).map{|part| part.to_i(16)} # Split into RGB parts as integers
        code = 16 + rgb.inject(0) {|kode, color| kode*6 + (color/256.0*6.0).floor}
        prefix = on ? 48 : 38
        "\e[#{prefix};5;#{code}m"
      elsif bright?
        Color.adjust_code(BASIC_COLORS[base_color], 60)
      else
        BASIC_COLORS[color]
      end
    end

    def encode(string)
      code + string + Color(:clear).code
    end
    
    def rgb
      if predefined?
        [red, green, blue]
      else
        raise "Unexpected color value #{@color.inspect}" unless @color =~ /^rgb_(\d{6})$/
        $1.scan(/../).map{|digits| digits.to_i(16)}
      end
    end
    
    # TODO The values for predefined colors could be improved; see http://en.wikipedia.org/wiki/ANSI_escape_code
    def red
      if predefined?
        value = @color.to_s =~ /red|magenta|yellow|white|gray|black/ ? 255 : 0
        value = value / 2 unless bright?
        value = value - 127 if value =~ /black/
        value
      else
        rgb[0]
      end
    end
    
    def green
      if predefined?
        value = @color.to_s =~ /green|yellow|cyan|white|gray|black/ ? 255 : 0
        value = value / 2 unless bright?
        value = value - 127 if value =~ /black/
        value
      else
        rgb[1]
      end
    end
    
    def blue
      if predefined?
        value = @color.to_s =~ /blue|magenta|cyan|white|gray|black/ ? 255 : 0
        value = value / 2 unless bright?
        value = value - 127 if value =~ /black/
        value
      else
        rgb[2]
      end
    end
    
    def to_s
      @color.to_s
    end
    
    def to_sym
      @color
    end
    
    def inspect
      @color.inspect
    end
  end
  
  class Style
    include Enumerable
    
    def self.rgb(*args)
      Style([StyleElement.rgb(*args)])
    end
    
    def self.on_rgb(*args)
      Style([StyleElement.on_rgb(*args)])
    end
    
    attr_reader :elements
    
    def initialize(from=[])
      replace(from)
    end
    
    def replace(from)
      @elements = from.map{|style| StyleElement(style)}
    end
    
    def size
      @elements.size
    end
    
    def code
      @elements.map{|element| element.code }.join
    end

    def encode(string)
      code + string + Color(:clear).code
    end
    
    def self.uncolor(string)
      string.gsub(/\e\[\d+(;\d+)*m/, '')
    end
    
    def to_syms
      @elements.map{|color| color.to_sym}
    end
    
    def +(from)
      @elements + coerce(from).elements
    end
    
    def self.coerce(from)
      Style(from)
    end
    
    def <<(from)
      @elements += Style(from).elements
    end
    
    def [](index)
      @elements[index]
    end
    
    def []=(index, value)
      @elements[index] = StyleElement(color)
    end
    
    def each(&blk)
      @elements.each(&blk)
    end
    
    def foreground
      color_style = @elements.reverse.find{|style| style.foreground }
      color = color_style.foreground if color_style
      color
    end
    alias_method :color, :foreground
    
    def background
      color_style = @elements.reverse.find{|style| style.background }
      color = color_style.background if color_style
      color
    end
    alias_method :on, :background
  end
end