# frozen_string_literal: true

module Color
  class RGB
    attr_accessor :r, :g, :b, :a

    def initialize(r, g, b, a)
      @r = [[r, 0].max, 255].min
      @g = [[g, 0].max, 255].min
      @b = [[b, 0].max, 255].min
      @a = [[a, 0].max, 100].min
    end

    def self.from_rgb(rgb)
      rgb.dup
    end

    def self.from_hsv(hsv)
      hsv.to_rgb
    end

    def to_rgb
      self
    end

    def to_hsv
      r_norm = @r / 255.0
      g_norm = @g / 255.0
      b_norm = @b / 255.0
      # Sticking with accuracy
      # See:
      #   https://en.wikipedia.org/wiki/HSL_and_HSV#From_HSV
      #   https://en.wikipedia.org/wiki/Rec._2020#RGB_and_luma-chroma_formats
      alpha = ((2 * r_norm) - g_norm - b_norm) / 2.0
      beta = (Math.sqrt(3) / 2) * (g_norm - b_norm)
      h_norm = Math.atan2(beta, alpha)
      chroma = ((alpha ** 2) + (beta ** 2)) ** 0.5
      # luma = (0.2627 * @r) + (0.67780 * @g) + (0.0593 * @b) # Not HSV
      v_norm = [r_norm, g_norm, b_norm].max
      s_vnorm = (v_norm == 0) ? 0 : (chroma / v)

      h = (180 * h_norm) / Math::PI
      s = s_vnorm * 100
      v = v_norm * 100
      HSV.new(h, s, v, @a)
    end

    def lerp(color, norm_percentage)
      # When lerping we want to guarantee the other color's value is used when norm_percentage == 1
      # See:
      #   https://en.wikipedia.org/wiki/Linear_interpolation#Programming_language_support
      rgb = color.to_rgb
      lerp_r = ((1 - norm_percentage) * @r) + (norm_percentage * rgb.r)
      lerp_g = ((1 - norm_percentage) * @g) + (norm_percentage * rgb.g)
      lerp_b = ((1 - norm_percentage) * @b) + (norm_percentage * rgb.b)
      lerp_a = ((1 - norm_percentage) * @a) + (norm_percentage * rgb.a)
      RGB.new(lerp_r, lerp_g, lerp_b, lerp_a)
    end
  end

  class HSV
    attr_accessor :h, :s, :v, :a

    def initialize(h, s, v, a = 100)
      @h = h % 360
      @s = [[s, 0].max, 100].min
      @v = [[v, 0].max, 100].min
      @a = [[a, 0].max, 100].min
    end

    def self.from(color)
      self.send("from_#{color.class.split('::').last.downcase}")
    end

    def self.from_rgb(rgb)
      rgb.to_hsv
    end

    def self.from_hsv(hsv)
      hsv.dup
    end

    def to_rgb
      # Constructed this way because it's guaranteed to return the same floating point result as h_norm from Color::RGB#to_hsv
      h_norm = (@h / 180.0) * Math::PI
      s_vnorm = @s / 100.0
      v_norm = @v / 100.0

      # Still sticking with accuracy
      # See:
      #   https://en.wikipedia.org/wiki/HSL_and_HSV#HSV_to_RGB_alternative
      f = lambda{|n|
        k = (n + (@h / 60.0)) % 6
        v_norm - (v_norm * s_vnorm * [0, [k, 4 - k, 1].min].max)
      }
      r_norm = f.call(5)
      g_norm = f.call(3)
      b_norm = f.call(1)

      r = r_norm * 255
      g = g_norm * 255
      b = b_norm * 255
      RGB.new(r, g, b, @a)
    end

    def to_hsv
      self
    end

    # Shortest path lerp (clockwise or anti-clockwise)
    def lerp(color, norm_percentage)
      # Excellent finds:
      #   https://www.alanzucconi.com/2016/01/06/colour-interpolation/
      #   https://stackoverflow.com/a/66654314
      hsv = color.to_hsv
      shortest_anti_clockwise = ((hsv.h - @h) % 360) <= 180
      if shortest_anti_clockwise
        self.aclerp(color, norm_percentage)
      else
        self.clerp(color, norm_percentage)
      end
    end

    # Clockwise lerp
    def clerp(color, norm_percentage)
      hsv = color.to_hsv
      hsv.aclerp(self, 1 - norm_percentage)
    end
    # Anti-clockwise lerp
    def aclerp(color, norm_percentage)
      hsv = color.to_hsv
      lerp_ac_h = ((1 - norm_percentage) * @h) + (norm_percentage * hsv.h)
      lerp_s    = ((1 - norm_percentage) * @s) + (norm_percentage * hsv.s)
      lerp_v    = ((1 - norm_percentage) * @v) + (norm_percentage * hsv.v)
      lerp_a    = ((1 - norm_percentage) * @a) + (norm_percentage * hsv.a)
      HSV.new(lerp_ac_h, lerp_s, lerp_v, lerp_a)
    end
  end

  class << self
    def rgb(r, g, b, a = 100)
      RGB.new(r, g, b, a)
    end
    def hsv(h, s, v, a = 100)
      HSV.new(h, s, v, a)
    end
  end
end