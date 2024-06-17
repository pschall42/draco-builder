# frozen_string_literal: true

require_relative 'base'
# require_relative '../../math_ext'

module Physics
  module Colliders
    # All Polygons are assumed to be convex, and will raise an error if they aren't. Concave polygons can be created via the AlgebraicCollider subclasses.
    class Polygon < Base
      attr_accessor :points
      # Assume the points are winding counter-clockwise to maintain compatibility with Box2D conventions
      def initialize(*points)
        @points = points
        raise "Polygon with #{self.winding} oriented points is not convex!\n\tpoints: #{points.inspect}" unless self.convex?
      end

      # [[0,0], [1, 0], [0.5, (1**2 - (0.5) ** 2) ** 0.5]] # Eq. triangle
      # [[0,0], [2, 0], [1, (1**2 - (0.5) ** 2) ** 0.5]] # Scaled [2, 1]
      # [[0,0], [1, 0], [0.5, 2 * (1**2 - (0.5) ** 2) ** 0.5]] # Scaled [1, 2]

      # [[10,10], [11, 10], [10.5, 10 + (1**2 - (0.5) ** 2) ** 0.5]] # Eq. triangle 2

      def convex?
        # Excellent finds:
        #   https://stackoverflow.com/a/45372025
        #   https://math.stackexchange.com/a/1745427
        @convex ||= lambda{
          # puts "self.convex_imp? #{self.convex_imp?}"
          # puts "self.convex_refactor? #{self.convex_refactor?}"
          raise "Difference between calcs" if self.convex_imp? != self.convex_refactor?
          self.convex_refactor?
        }.call()
      end

      def convex_imp?
        return false if self.points.size < 3
        w_sign = 0 # first nonzero orientation

        x_sign = 0
        x_first_sign = 0 # sign of first nonzero edge vector x
        x_flips = 0 # number of sign changes in x

        y_sign = 0
        y_first_sign = 0 # sign of first nonzero edge vector y
        y_flips = 0 # number of sign changes in y

        curr_point = self.points[-2] # second-to-last vertex
        next_point = self.points[-1] # last vertex
        self.points.each do |point| # each vertex, in order
          prev_point = curr_point # previous vertex
          curr_point = next_point # current vertex
          next_point = point # next vertex

          # Previous edge vector ("before"):
          bx = curr_point[0] - prev_point[0]
          by = curr_point[1] - prev_point[1]

          # Next edge vector ("after"):
          ax = next_point[0] - curr_point[0]
          ay = next_point[1] - curr_point[1]

          # Calculate sign flips using the next edge vector ("after"), recording the first sign.
          if ax > 0
            if x_sign == 0
              x_first_sign = 1
            elsif x_sign < 0
              x_flips += 1
            end
            x_sign = 1
          elsif ax < 0
            if x_sign == 0
              x_first_sign = -1
            elsif x_sign > 0
              x_flips += 1
            end
            x_sign = -1
          end
          return false if x_flips > 2

          if ay > 0
            if y_sign == 0
              y_first_sign = 1
            elsif y_sign < 0
              y_flips += 1
            end
            y_sign = 1
          elsif ay < 0
            if y_sign == 0
              y_first_sign = -1
            elsif y_sign > 0
              y_flips += 1
            end
            y_sign = -1
          end
          return false if y_flips > 2

          # Find out the orientation of this pair of edges, and ensure it does not differ from previous ones.
          w = (bx * ay) - (ax * by)
          if (w_sign == 0) && (w != 0)
            w_sign = w
          elsif (w_sign > 0) && (w < 0)
            return false
          elsif (w_sign < 0) && (w > 0)
            return false
          end
        end

        # Final/wraparound sign flips:
        if (x_sign != 0) && (x_first_sign != 0) && (x_sign != x_first_sign)
          x_flips = x_flips + 1
        end
        if (y_sign != 0) && (y_first_sign != 0) && (y_sign != y_first_sign)
          y_flips = y_flips + 1
        end

        # Concave polygons have two sign flips along each axis.
        return false if (x_flips != 2) || (y_flips != 2)

        # This is a convex polygon.
        true
      end

      def convex_refactor?
        # puts "START :convex_refactor"
        # Take from the second to last point up through the rest of the points
        axis_trackers = (-2..(self.points.size - 1)).each_cons(3).reduce({axis_trackers: [], last_orientation_sign: nil}){|acc, prev_current_next_idxs|
          # Extract previous, current, and next points
          prev_point, current_point, next_point = prev_current_next_idxs.map{|idx| self.points[idx]}
          # Previous edge vector (before)
          before_edge_vector = current_point.each_with_index.map{|current_axis_value, axis_idx|
            current_axis_value - prev_point[axis_idx]
          }
          # Next edge vector (after)
          after_edge_vector = next_point.each_with_index.map{|next_axis_value, axis_idx|
            next_axis_value - current_point[axis_idx]
          }
          # puts "Debug: #{
          #   {prev_point: prev_point, current_point: current_point, next_point: next_point, before_edge_vector: before_edge_vector, after_edge_vector: after_edge_vector}.inspect
          # }"

          # Calculate sign flips, recording the first sign
          after_edge_vector.each_with_index{|after_vector_axis_value, axis_idx|
            after_vector_axis_sign = after_vector_axis_value <=> 0
            axis_tracker = acc[:axis_trackers][axis_idx] || {sign: 0, first_sign: 0, flips: 0}

            if after_vector_axis_sign != 0
              # Set the first sign
              axis_tracker[:first_sign] = after_vector_axis_sign if axis_tracker[:sign] == 0
              # Increment the flips if the signs are different after the first sign, which can only be true when they sum to 0
              axis_tracker[:flips] += 1 if (axis_tracker[:sign] + after_vector_axis_sign) == 0
              # Set the current sign
              axis_tracker[:sign] = after_vector_axis_sign
            end
            return false if axis_tracker[:flips] > 2
          }

          # Find out the orientation of this pair of edges, if it differs from the previous ones it
          orientation = MathExt::Vector.cross_product(before_edge_vector, after_edge_vector)[2] <=> 0
          acc[:last_orientation_sign] ||= orientation
          # puts "acc: #{acc.inspect}"# if acc[:last_orientation_sign] != orientation
          return false if acc[:last_orientation_sign] != orientation

          acc
        }[:axis_trackers]

        # Final/wraparound sign flips:
        axis_trackers.each{|axis_tracker|
          axis_tracker[:flips] += 1 if (axis_tracker[:sign] != 0) && (axis_tracker[:first_sign] != 0) && (axis_tracker[:sign] != axis_tracker[:first_sign])
          # Convex polygons have exactly 2 sign flips along each axis, otherwise concave
          # puts "AXIS_TRACKER 2 : #{axis_tracker.inspect}"# if axis_tracker[:flips] != 2
          return false if axis_tracker[:flips] != 2
        }

        # Should be convex if we made it this far
        true
      end

      def center
        # Since we need to loop through all the edges anyway and doing so multiple times would waste resources, we just perform the same reduction as the :double_area method with some additional info
        # See:
        #   https://en.wikipedia.org/wiki/Centroid#Of_a_polygon
        reduction = self.edges.reduce({dbl_area: 0, cx_sum: 0, cy_sum: 0}){|acc, edge|
          # Unpack the values
          v1, v2 = edge
          v1_x, v1_y = v1
          v2_x, v2_y = v2
          # Perform the reductions
          shoelace = (v2_x - v1_x) * (v2_y + v1_y)
          acc[:dbl_area] += shoelace
          acc[:cx_sum] += (v1_x + v2_x) * shoelace
          acc[:cy_sum] += (v1_y + v2_y) * shoelace
          acc
        }
        coefficient = (1.0 / (reduction[:dbl_area] * 3.0))
        cx = coefficient * reduction[:cx_sum]
        cy = coefficient * reduction[:cy_sum]
        # Return the center
        [cx, cy]
      end

      def edges
        # Can't use slice because the Ruby won't wraparound with negative indices
        @edges ||= (-1..(self.points.size - 1)).each_cons(2).reduce([]){|acc, idxs|
          acc << idxs.map{|idx| self.points[idx]}
          acc
        }.tap{|es|
          # Need to shift the first edge to the back to maintain point order
          es << es.shift
        }
      end

      def winding
        # All excellent finds, taking the fastest solution though (the last link):
        #   https://stackoverflow.com/a/11596795
        #   https://stackoverflow.com/a/1165943
        #   https://stackoverflow.com/a/1180256
        @winding ||= self.winding_by_convex_hull
      end

      def winding_by_convex_hull
        # See:
        #   https://stackoverflow.com/a/1180256

        # Skip determining a hull middle point if we already know if it's convex
        @hull_middle_point ||= self.points[1] if @convex

        # Skip determining a hull middle point if we've already calculated it
        @hull_middle_point ||= lambda{
          extremes_zero = {
            x: {
              min: {value: nil, points: []},
              max: {value: nil, points: []},
            },
            y: {
              min: {value: nil, points: []},
              max: {value: nil, points: []}
            }
          }

          # Accumulation helper
          accumulate_points_fn = lambda{|acc, candidate_coord_val, candidate_point, base_path, min_or_max = :min|
            acc_base = base_path.empty? ? acc : acc.dig(*base_path)
            puts "#{{acc: acc, candidate_coord_val: candidate_coord_val, candidate_point: candidate_point, base_path: base_path, min_or_max: min_or_max, acc_base: acc_base}.inspect}"
            # When we initialize it, the first comparison is guaranteed to be 0
            acc_base[:value] ||= candidate_coord_val
            restart_sign = (min_or_max == :min) ? -1 : 1
            case candidate_coord_val <=> acc.dig(*base_path, :value)
            when restart_sign
              # Restart the accumulation
              acc_base[:value] = candidate_coord_val
              acc_base[:points].reject!{|_| true}
              acc_base[:points] << candidate_point
            when 0
              acc_base[:points] << candidate_point
            end
          }
          # Find all the extremeties in one loop
          extremes = self.points.reduce(extremes_zero){|acc, candidate_point|
            candidate_x, candidate_y = candidate_point
            accumulate_points_fn.call(acc, candidate_x, candidate_point, [:x, :min], :min)
            accumulate_points_fn.call(acc, candidate_x, candidate_point, [:x, :max], :max)
            accumulate_points_fn.call(acc, candidate_y, candidate_point, [:y, :min], :min)
            accumulate_points_fn.call(acc, candidate_y, candidate_point, [:y, :max], :max)
            acc
          }
          pick_solo_point_fn = lambda{|ps| ps.size > 1 ? nil : ps[0] }
          # Pick the point with the smallest x coordinate
          hull_middle_point = extremes.dig(:x, :min, :points).yield_self(&pick_solo_point_fn)
          # Pick the point with the smallest y coordinate (if not picked)
          hull_middle_point ||= extremes.dig(:y, :min, :points).yield_self(&pick_solo_point_fn)
          # Pick the point with the smallest y coordinate among the ones with the largest x coordinate (if not picked)
          hull_middle_point ||= (extremes.dig(:y, :max, :points).reduce({value: nil, points: []}){|acc, max_x_point|
            candidate_y = max_x_point[1]
            accumulate_points_fn.call(acc, candidate_y, max_x_point, [], :min)
            acc
          })[:points].yield_self(&pick_solo_point_fn)
          # Pick the point with the smallest x coordinate among the ones with the largest y coordinate (if not picked)
          hull_middle_point ||= (extremes.dig(:y, :max, :points).reduce({value: nil, points: []}){|acc, max_y_point|
            candidate_x = max_y_point[0]
            accumulate_points_fn.call(acc, candidate_x, max_y_point, [], :min)
            acc
          })[:points].yield_self(&pick_solo_point_fn)
        }.call()

        # Find the previous and next points
        hull_middle_point = @hull_middle_point # Just an easier name to avoid typing the @
        hull_middle_idx = self.points.index(hull_middle_point)
        hull_prev_point = self.points[hull_middle_idx - 1]
        hull_next_point = self.points[(hull_middle_idx + 1) % self.points.size]

        # Find the sign of the cross product of [hull_middle_point, hull_prev_point] and [hull_middle_point, hull_next_point]
        # See:
        #   https://en.wikipedia.org/wiki/Curve_orientation#Practical_considerations
        determinant = (
          (hull_middle_point[0] - hull_prev_point[0]) * (hull_next_point[1] - hull_prev_point[1])
        ) - (
          (hull_next_point[0] - hull_prev_point[0]) * (hull_middle_point[1] - hull_prev_point[1])
        )

        # Clockwise if the determinant is negative, counter clockwise if the determinant is positive
        case determinant <=> 0
        when -1
          :clockwise
        when 1
          :counter_clockwise
        else # Invalid
          raise "Polygon has an invalid winding!\n\tpoints: #{points.inspect}"
        end
      end

      def double_area
        self.edges.reduce(0){|acc, edge|
          # Unpack the values
          v1, v2 = edge
          v1_x, v1_y = v1
          v2_x, v2_y = v2
          # Perform the reduction
          acc + (v2_x - v1_x) * (v2_y + v1_y)
        }
      end

      def area
        self.double_area / 2.0
      end

      def winding_by_area
        # See:
        #   https://stackoverflow.com/a/11596795
        #   https://stackoverflow.com/a/1165943
        dbl_area = self.double_area
        case dbl_area <=> 0
        when -1
          :counter_clockwise
        when 1
          :clockwise
        else
          raise "Polygon has an invalid winding!\n\tpoints: #{points.inspect}"
        end
      end

      def axis_aligned_bounding_box
        @aabb ||= lambda{
          tr_bl = self.points.reduce({tr: [], bl: []}){|acc, point|
            acc[:tr][0] = point[0] if acc[:tr][0].nil? || acc[:tr][0] > point[0] # top-right x
            acc[:tr][1] = point[1] if acc[:tr][1].nil? || acc[:tr][1] > point[1] # top-right y
            acc[:bl][0] = point[0] if acc[:bl][0].nil? || acc[:bl][0] < point[0] # bottom-left x
            acc[:bl][1] = point[1] if acc[:bl][1].nil? || acc[:bl][1] < point[1] # bottom-left y
            acc
          }
          {
            x: tr_bl[:bl][0],
            y: tr_bl[:bl][1],
            w: tr_bl[:tr][0] - tr_bl[:bl][0],
            h: tr_bl[:tr][1] - tr_bl[:bl][1]
          }
        }.call()
      end
      alias_method :aabb, :axis_aligned_bounding_box

      def outward_normals
        # TODO: Get this to work, see:
        #   https://gamedev.stackexchange.com/questions/26951/calculating-the-2d-edge-normals-of-a-triangle
        #   https://stackoverflow.com/questions/22838071/robust-polygon-normal-calculation
        #   https://www.khronos.org/opengl/wiki/Calculating_a_Surface_Normal
        #   https://stackoverflow.com/questions/11548309/guarantee-outward-direction-of-polygon-normals
        winding_type = self.winding
        @outward_normals ||= self.edges.map{|(x, y)|
          case winding_type
          when :clockwise
            MathExt::Vector.normalize([y, -x])
          when :counter_clockwise
            MathExt::Vector.normalize([-y, x])
          end
        }
      end
      def inward_normals
        # This is just the outward normals sign-flipped
        @inward_normals ||= self.outward_normals.map{|(x, y)|
          [-x, -y]
        }
      end
    end
  end
end
