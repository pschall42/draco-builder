# frozen_string_literal: true

require_relative 'base'

module Physics
  module Colliders
    class AlgebraicCollider < Base
      attr_accessor :colliders, :center
      def initialize(*colliders, center: nil)
        @colliders = colliders.flatten
        # By default, the center should be at the center of each of the colliders, weighted by the area of each collider (a sort of pseudo center of mass)
        @center = center || @colliders.reduce({wcs: [], tw: 0}){|acc, collider|
          # Weight each center point by the area, where:
          #   :wcs == weighted centers
          #   :tw == total weight
          collider_weight = collider.area
          collider_center = collider.center.to_a
          acc[:wcs] << collider_center.map{|v| v * collider_weight}
          acc[:tw] += collider_weight
          acc
        }.tap{|weighted|
          weighted[:center] = weighted[:wcs].reduce([]){|axis_sums, weighted_center|
            # Calculate the sum of each weighted axis component
            weighted_center.each_with_index{|weighted_value, idx|
              axis_sums[idx] = (axis_sums[idx] || 0) + weighted_value
            }
            axis_sums
          }.map{|axis_sum|
            # Divide each axis sum by the total weight
            axis_sum / weighted[:tw]
          }[:center]
        }
      end

      def area
        self.colliders.reduce(0){|acc, collider| acc + collider.area}
      end
    end
  end
end
