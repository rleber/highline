#!/usr/local/bin/ruby -w

# color_scheme.rb
#
# Created by Richard LeBer on 2011-06-27.
# Copyright 2011.  All rights reserved
#
# This is Free Software.  See LICENSE and COPYING for details

class HighLine
  
  def self.Style(*args)
    args = args.compact.flatten
    if args.size==1
      arg = args.first
      if arg.is_a?(Style)
        Style.list[arg.name] || Style.index(arg)
      elsif arg.is_a?(::String) && arg =~ /^\e\[/ # arg is a code
        if styles = Style.code_index[arg]
          styles.first
        else
          Style.new(:code=>arg)
        end
      elsif style = Style.list[arg]
        style
      elsif HighLine.color_scheme && HighLine.color_scheme[arg]
        HighLine.color_scheme[arg]
      elsif arg.is_a?(Hash)
        Style.new(arg)
      elsif arg.to_s.downcase =~ /^rgb_([a-f0-9]{6})$/
        Style.rgb($1)
      elsif arg.to_s.downcase =~ /^on_rgb_([a-f0-9]{6})$/
        Style.rgb($1).on
      else
        raise NameError, "#{arg.inspect} is not a defined Style"
      end
    else
      name = args
      Style.list[name] || Style.new(:list=>args)
    end
  end
  
  class Style
    
    def self.index(style)
      if style.name
        @@styles ||= {}
        @@styles[style.name] = style
      end
      if !style.list
        @@code_index ||= {}
        @@code_index[style.code] ||= []
        @@code_index[style.code].reject!{|indexed_style| indexed_style.name == style.name}
        @@code_index[style.code] << style
      end
      style
    end
    
    def self.rgb_hex(*colors)
      colors.map do |color|
        color.is_a?(Numeric) ? '%02x'%color : color.to_s
      end.join
    end
    
    def self.rgb_parts(hex)
      hex.scan(/../).map{|part| part.to_i(16)}
    end
    
    def self.rgb(*colors)
      hex = rgb_hex(*colors)
      name = ('rgb_' + hex).to_sym
      if style = list[name]
        style
      else
        parts = rgb_parts(hex)
        new(:name=>name, :code=>"\e[38;5;#{rgb_number(parts)}m", :rgb=>parts)
      end
    end
    
    def self.rgb_number(*parts)
      parts = parts.flatten
      16 + parts.inject(0) {|kode, part| kode*6 + (part/256.0*6.0).floor}
    end
    
    def self.list
      @@styles ||= {}
    end
    
    def self.code_index
      @@code_index ||= {}
    end
    
    def self.uncolor(string)
      string.gsub(/\e\[\d+(;\d+)*m/, '')
    end
    
    # TODO Other coordinates, e.g. HSL, HSI, YUV, CIELAB (http://en.wikipedia.org/wiki/Lab_color_space)?
    # TODO Separate coordinate conversions into a different library/mixin
    
    # Convert RGB color encoding to HSV (aka HSB)
    # For mathematics and explanation, see http://en.wikipedia.org/wiki/HSL_and_HSV
    # Based on code by unclekyky at http://forum.junowebdesign.com/general-programming/29744-conversion-hsv-hsl-back.html
    def self.rgb_to_hsv(rgb)
      rgb = rgb.map{|coord| coord/255.0}
      max = rgb.max
      min = rgb.min
      delta = max - min
      h = if max == rgb[0]    # max is red
        h = (60.0*((rgb[1]-rgb[2])/delta)) % 360
      elsif max == rgb[1]     # max is green
        h = 60.0*((rgb[2]-rgb[0])/delta) + 120
      else                    # max is blue
        h = 60.0*((rgb[0]-rgb[1])/delta) + 240
      end
      v = max
      s = max != 0.0 ? delta/max : 0
      [h, s*100.0, v*100.0]
    end

    # Convert HSV color encoding (aka HSB) to RGB
    # For mathematics and explanation, see http://en.wikipedia.org/wiki/HSL_and_HSV
    def self.hsv_to_rgb(hsv)
      h, s, v = hsv
      s = s/100.0
      v = v/100.0
      c = s*v
      h_prime = (h/60.0).floor
      x = c*(1-(h_prime%2-1).abs)
      m = v - c
      rgb = case h_prime
      when 0 then [c+m, x,   m  ]
      when 1 then [x+m, c+m, m  ]
      when 2 then [m,   c+m, x+m]
      when 3 then [m,   x+x, c+m]
      when 4 then [x+m, m,   c+m]
      else        [c+m, m,   x+m]
      end
      rgb.map{|coord| coord*255.0}
    end
    
    attr_reader :name, :code, :list, :rgb
    attr_accessor :builtin
    
    # Single color/styles have :name, :code, :rgb (possibly), :builtin
    # Compound styles have :name, :list, :builtin
    # hsv is computed on the fly (and cached)
    def initialize(defn = {})
      @definition = defn
      @name    = defn[:name]
      @code    = defn[:code]
      @rgb     = defn[:rgb]
      @hsv     = nil
      @list    = defn[:list]
      @builtin = defn[:builtin]
      if @rgb
        hex = self.class.rgb_hex(@rgb)
        rgb = self.class.rgb_parts(hex)
        @name ||= 'rgb_' + hex
      elsif @list
        @name ||= @list
      end
      self.class.index self unless defn[:no_index]
    end
    
    def dup
      self.class.new(@definition)
    end
    
    def to_hash
      @definition
    end
    
    def color(string)
      code + string + HighLine::CLEAR
    end
    
    def code
      if @list
        @list.map{|element| HighLine.Style(element).code}.join
      else
        @code
      end
    end
      
    def red
      @rgb && @rgb[0]
    end

    def green
      @rgb && @rgb[1]
    end

    def blue
      @rgb && @rgb[2]
    end
    
    def rgb=(rgb_value)
      @rgb=rgb_value
      @hsv = nil
    end
    
    def hsv
      @hsv ||= self.class.rgb_to_hsv(@rgb)
    end
    
    def hsv=(hsv_value)
      @hsv = hsv_value
      @rgb = self.class.hsv_to_rgb(@hsv)
    end
    
    def variant(new_name, options={})
      raise "Cannot create a variant of a style list (#{inspect})" if @list
      new_code = options[:code] || code
      if options[:code_increment]
        raise "Unexpected code in #{inspect}" unless new_code =~ /^(.*?)(\d+)(.*)/
        new_code = $1 + ($2.to_i + options[:increment]).to_s + $3
      end
      new_rgb = if options[:rgb]
        options[:rgb]
      elsif options[:hsv]
        self.class.hsv_to_rgb(options[:hsv])
      else 
        @rgb
      end
      if options[:rgb_increment]
        options[:rgb_increment].each_with_index {|incr, i| new_rgb[i] += incr}
      elsif options[:hsv_increment]
        new_hsv = self.class.rgb_to_hsv(new_rgb)
        options[:hsv_increment].each_with_index {|incr, i| new_hsv[i] += incr}
        new_rgb = self.class.hsv_to_rgb(new_hsv)
      end
      new_style = self.class.new(self.to_hash.merge(:name=>new_name, :code=>new_code, :rgb=>new_rgb))
    end
    
    def on
      new_name = ('on_'+@name.to_s).to_sym
      self.class.list[new_name] ||= variant(new_name, :code_increment=>10)
    end
    
    def bright
      raise "Cannot create a bright variant of a style list (#{inspect})" if @list
      new_name = ('bright_'+@name.to_s).to_sym
      if style = self.class.list[new_name]
        style
      else
        new_rgb = @rgb == [0,0,0] ? [128, 128, 128] : @rgb.map {|color|  color==0 ? 0 : [color+128,255].min }
        variant(new_name, :code_increment=>60, :rgb=>new_rgb)
      end
    end
  end
end
