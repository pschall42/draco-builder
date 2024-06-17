# frozen_string_literal: true

module MathExt
  module Vector
    class << self
      def is_vector?(maybe_vector)
        maybe_vector.is_a?(Array) && maybe_vector.all?{|v| v.is_a?(Numeric)}
      end

      def cross_product(vector_1, vector_2)
        # The arrays are considered vectors, any additional elements beyond the first 3 axes are ignored, and any missing elements are considered as 0
        a = [].fill(0..2){|idx| vector_1[idx] || 0}
        b = [].fill(0..2){|idx| vector_2[idx] || 0}
        [
          (a[1] * b[2]) - (a[2] * b[1]),
          (a[2] * b[0]) - (a[0] * b[2]),
          (a[0] * b[1]) - (a[1] * b[0])
        ]
      end

      def dot_product(vector_1, vector_2)
        # The arrays are considered vectors, any additional elements beyond the first 3 axes are ignored, and any missing elements are considered as 0
        as = [].fill(0..2){|idx| vector_1[idx] || 0}
        bs = [].fill(0..2){|idx| vector_2[idx] || 0}
        as.each_with_index.reduce(0){|acc, (a, idx)|
          b = bs[idx]
          acc + (a * b)
        }
      end

      def normalize(vector)
        magnitude = vector.reduce(0){|acc, v| acc + (v ** 2)} ** 0.5
        vector.map{|v| v / magnitude}
      end

      def project_onto_axis(axis, points)
        points.reduce({min: nil, max: nil}){|acc, point|
          projected = MathExt.dot_product(axis, point)
          acc[:min] = projected if acc[:min].nil? || projected < acc[:min]
          acc[:max] = projected if acc[:max].nil? projected > acc[:max]
          acc
        }
      end
    end
  end

  module Matrix
    class << self
      def row_count(matrix)
        matrix.size
      end
      def column_count(matrix)
        column_counts = matrix.map(&:size)
        raise ("#{matrix} is not a matrix") if column_counts.uniq.size != 1
        column_counts[0]
      end
      def is_matrix?(maybe_matrix)
        maybe_matrix.is_a?(Array) && maybe_matrix.reduce({all: true, columns: nil}){|acc, v|
          if acc[:all]
            acc[:columns] ||= v.size
            acc[:all] = acc[:all] && (acc[:columns] == v.size)
          end
          acc
        }[:all]
      end
      def multiply(*matrices)
        # Based on this implementation:
        #   https://github.com/ruby/matrix/blob/f803b143c10283fcb748b9fb9519924de7326d8e/lib/matrix.rb#L1052-L1085
        matrices.reduce{|matrix_1, matrix_2|
          if ::MathExt::Vector.is_vector?(matrix_2)
            # Special optimization if matrix_2 is a vector, this is to prevent having to create several nested arrays that are only necessary to communicate the column structure (eg. instead of having to specify and pass [[1], [2], [3]] you can just pass [1, 2, 3])
            m1_column_count = self.column_count(matrix_1)
            m2_column_count = 1

            m1_row_count = self.row_count(matrix_1)
            m2_row_count = matrix_2.size

            raise "Cannot multiply #{m1_row_count}×#{m1_column_count} matrix by #{m2_row_count}×#{m2_column_count} matrix, the column count of the first matrix must match the row count of the second matrix!" if m1_column_count != m2_row_count

            m1_row_count.times.map.map{|i_idx|
              [m2_row_count.times.reduce(0){|acc, j_idx|
                acc + matrix_1[i_idx][j_idx] * matrix_2[j_idx]
              }]
            }
          else
            # Perform a regular matrix multiplication
            m1_column_count = self.column_count(matrix_1)
            m2_column_count = self.column_count(matrix_2)

            m1_row_count = self.row_count(matrix_1)
            m2_row_count = self.row_count(matrix_2)

            raise "Cannot multiply #{m1_row_count}×#{m1_column_count} matrix by #{m2_row_count}×#{m2_column_count} matrix, the column count of the first matrix must match the row count of the second matrix!" if m1_column_count != m2_row_count

            m1_row_count.times.map{|i_idx|
              Array.new(m2_column_count){|j_idx|
                m1_column_count.times.reduce(0){|acc, k_idx|
                  acc + matrix_1[i_idx][k_idx] * matrix_2[k_idx][j_idx]
                }
              }
            }
          end
        }
      end

      def test
        self.multiply(
          [
            [3, 5],
            [-1, 1]
          ],
          [
            [-2, 2, 3],
            [3, 5, -2]
          ]
        ) == [
          [9, 31, -1],
          [5, 3, -5]
        ]
      end
    end
  end



  class << self
    # Non-mutating form of :numeric_integration!
    def numeric_integration(components_hash, integration_mapping)
      component_keys = integration_mapping.to_a.flatten.uniq
      # puts ({components_hash: components_hash, integration_mapping: integration_mapping, component_keys: component_keys, arg_0: components_hash.clone}.inspect)

      # components_hash_dup = components_hash.reduce({}){|acc, (component_key, component)|
      #   acc[component_key] = component.reduce({}){|comp_acc, (comp_attr_key, comp_attr_val)|
      #     comp_acc[comp_attr_key] = comp_attr_val
      #   }
      #   acc
      # }

      self.numeric_integration!(components_hash.clone.slice(*component_keys), integration_mapping)
    end

    # Takes a Hash of components and runs the integration_mapping on them, changing the individual values of each component by its corresponding derivative component. If any component is missing values, it will default to 0.
    #
    # For example, if components_hash is:
    #   {
    #     position:     {x: 10, y: 10},
    #     velocity:     {x:  2, y: -2},
    #     acceleration: {x: -1, y:  3},
    #     jerk:         {x:  5       },
    #     snap:         {       y: -2}
    #   }
    # And integration_mapping is:
    #   {
    #     position:     :velocity,
    #     velocity:     :acceleration,
    #     acceleration: :jerk
    #     jerk:         :snap
    #   }
    # It will update components_hash to:
    #   {
    #     position:     {x: 12, y:  8},
    #     velocity:     {x:  1, y:  1},
    #     acceleration: {x:  4, y:  3},
    #     jerk:         {x:  5, y: -2},
    #     snap:         {x:  0, y: -2}
    #   }
    # Which is the result of numerically integrating each of the components by the derivatives.
    def numeric_integration!(components_hash, integration_mapping)
      # Find all integration components
      components = integration_mapping.reduce({}){|acc, (integration_key, derivative_key)|
        acc[integration_key] = components_hash[integration_key] || {}
        acc[derivative_key] = components_hash[derivative_key] || {}
        acc
      }

      # Intialize components. For physics motion this will actually work for any arbitrary set of dimensions, so if the engine is expanded to work with 3D it can work with 3D, and if you want to make a 4D game from that it can work with 4D, and so on.
      component_vars = components.reduce([]){|acc, (_, comp)|
        comp.reduce(acc){|acc_2, (k, _)|
          acc_2 << k if !acc_2.include?(k)
          acc_2
        }
      }
      component_vars.each{|comp_var|
        components.each{|_, comp|
          comp[comp_var] ||= 0
        }
      }
      # component_vars = components.reduce({}){|lookup_acc, (comp_name, comp)|
      #   lookup_acc[comp_name] = comp.reduce([]){|vars_acc, (k, _)|
      #     vars_acc << k if !vars_acc.include?(k)
      #     vars_acc
      #   }
      #   lookup_acc
      # }
      # component_vars.each{|comp_name, comp_vars|
      #   comp_vars.each{|comp|
      #     components[comp_name][comp] ||= 0
      #   }
      # }

      # Integrate
      components.each{|comp_name, comp|
        delta_comp_name = integration_mapping[comp_name]
        if !delta_comp_name.nil?
          delta_comp = components[delta_comp_name]
          component_vars.each{|comp_var|
            comp[comp_var] += delta_comp[comp_var]
          }
        end
      }
      components
    end

    def weighted_random_select(*weighted_options)
      weighted_options.flatten!
      total_weight, norm_weighted_options = weighted_options.reduce({total: 0, norm_weighted: []}){|acc, opt|
        acc[:total] += opt[:weight]
        acc[:norm_weighted] << opt.merge(threshold: acc[:total])
        acc
      }.values_at(:total, :norm_weighted)
      total_weight = total_weight.to_f
      norm_weighted_options.map!{|opt|
        opt[:threshold] = opt[:threshold] / total_weight
        opt
      }
      rng_pick = rand()
      # puts "rng_pick: #{rng_pick} norm_weighted_options: #{norm_weighted_options.inspect}"
      norm_weighted_options.detect{|opt| rng_pick < opt[:threshold] }
    end

    def change_linear_scales(n_in_scale_1, scale_1, scale_2)
      scale_1_min, scale_2_min = scale_1.min, scale_2.min
      scale_1_diff = (scale_1.max - scale_1_min).to_f
      scale_2_diff = (scale_2.max - scale_2_min).to_f
      n_in_scale_1_diff = n_in_scale_1 - scale_1_min
      ((scale_2_diff / scale_1_diff) * n_in_scale_1_diff) + scale_2_min
    end
  end
end
