# frozen_string_literal: true

require_relative 'color'

module Background
  class << self
    def vertical_gradiant(color_1, color_2, grid, &curve_fn)
      h_float = grid.h.to_f
      grid.h.times.map{|y|
        y_progression = y / h_float
        y_curved = curve_fn.nil? ? y_progression : curve_fn.call(y_progression, y, h_float)
        rgba = color_1.lerp(color_2, y_curved).to_rgb
        {
          x: 0, y: y, w: grid.w, h: 1,
          r: rgba.r, g: rgba.g, b: rgba.b, a: rgba.a
        }
      }
    end
    def horizontal_gradiant(color_1, color_2, grid, &curve_fn)
      w_float = grid.w.to_f
      grid.w.times.map{|x|
        x_progression = x / w_float
        x_curved = curve_fn.nil? ? x_progression : curve_fn.call(x_progression, x, w_float)
        rgba = color_1.lerp(color_2, x_curved).to_rgb
        {
          x: x, y: 0, w: 1, h: grid.h,
          r: rgba.r, g: rgba.g, b: rgba.b, a: rgba.a
        }
      }
    end
    # Unfortunately this generates too many objects to actually render a gradiant, need to look into generating pixel arrays instead of a shit ton of objects
    def diagonal_gradiant(x_color_1, x_color_2, y_color_1, y_color_2, grid, x_curve_fn: nil, y_curve_fn: nil, &pixel_curve_fn)
      w_float = grid.w.to_f
      h_float = grid.h.to_f
      grid.w.times.reduce([]){|acc_outer, x|
        x_progression = (x / w_float)
        x_curved = x_curve_fn.nil? ? x_progression : x_curve_fn.call(x_progression, x, w_float)
        x_color = x_color_1.lerp(x_color_2, x_curved)
        grid.h.times.reduce(acc_outer){|acc_inner, y|
          y_progression = (y / w_float)
          y_curved = y_curve_fn.nil? ? y_progression : y_curve_fn.call(y_progression, y, h_float)
          y_color = y_color_1.lerp(y_color_2, y_curved)
          # Both progressions will be 0 initially, so to avoid divide by 0 errors, we default to 0.5
          diag_progression = x_progression + y_progression
          pixel_progression = (diag_progression == 0) ? 0.5 : x_progression / diag_progression
          pixel_curve = pixel_curve_fn.nil? ? pixel_progression : pixel_curve_fn.call(
            pixel_progression: pixel_progression,
            diag_progression: diag_progression,
            x_progression: x_progression,
            y_progression: y_progression,
            x_curved: x_curved,
            y_curved: y_curved,
            x: x,
            y: y,
            w_float: w_float,
            h_float: h_float
          )
          rgba_pixel = x_color.lerp(y_color, pixel_curve).to_rgb
          acc_inner << {
            x: x, y: y, w: 1, h: 1,
            r: rgba_pixel.r, g: rgba_pixel.g, b: rgba_pixel.b, a: rgba_pixel.a
          }
          acc_inner
        }
        acc_outer
      }
    end

    def sky(grid, recreate: false)
      @sky ||= {}
      # @sky[[grid.w, grid.h]] ||= [
      #   {
      #     x: 0, y: 0, w: grid.w, h: grid.h,
      #     r: 103, g: 209, b: 252, a: 191
      #   }
      # ]
      @sky[[grid.w, grid.h]] = nil if recreate
      @sky[[grid.w, grid.h]] ||= lambda{
        deepest_sky_blue = Color.hsv(211, 100, 100, 100)
        lightest_sky_blue = Color.hsv(189, 24, 99, 100)
        self.vertical_gradiant(
          lightest_sky_blue,
          deepest_sky_blue,
          grid
        )
        # self.horizontal_gradiant(
        #   lightest_sky_blue,
        #   deepest_sky_blue,
        #   grid
        # )
        # self.diagonal_gradiant(deepest_sky_blue, lightest_sky_blue, lightest_sky_blue, deepest_sky_blue, grid)
      }.call()
    end
  end
end
