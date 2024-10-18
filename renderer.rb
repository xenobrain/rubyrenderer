module Renderer
  @layers = Hash.new { |h, k| h[k] = [] }
  @layer_contexts = {}
  @sorted_layers = []
  @draw_wireframe = true

  class << self
    attr_accessor :camera, :light, :layers, :draw_wireframe,

    def new_layer(name, z, projection, type = :sprite, parallax_table = nil, depth_table = nil)
      @layer_contexts[name] = { z: z, name: name, type: type,projection: projection, depth_table: depth_table, parallax_table: parallax_table }
      @sorted_layers = @layer_contexts.sort_by { |_, context| context[:z] }
      @layers[name]
    end

    def tick
      calc_camera
      $gtk.args.outputs.primitives << self
    end

    def draw_override ffi
      draw_mesh_layer_perspective @layers[:foreground_mesh], ffi
    end

    def calc_camera
      @zoom = @camera[:zoom]
      @up_x = @camera[:up_x]
      @up_y = @camera[:up_y]
      @up_z = @camera[:up_z]
      @camera_x = @camera[:x]
      @camera_y = @camera[:y]
      @camera_z = @camera[:z]
      target_x = @camera[:target][:x]
      target_y = @camera[:target][:y]
      target_z = @camera[:target][:z]
      @h_fov = Math.tan(@camera[:fov] * DEG2RAD * 0.5)

      # Calculate the camera's forward vector
      @forward_x = target_x - @camera_x
      @forward_y = target_y - @camera_y
      @forward_z = target_z - @camera_z
      forward_length = 1.0 / Math.sqrt(@forward_x*@forward_x + @forward_y*@forward_y + @forward_z*@forward_z)
      @forward_x *= forward_length
      @forward_y *= forward_length
      @forward_z *= forward_length

      # Calculate the camera's right vector
      @right_x = @forward_y * @up_z - @forward_z * @up_y
      @right_y = @forward_z * @up_x - @forward_x * @up_z
      @right_z = @forward_x * @up_y - @forward_y * @up_x
      right_length = 1.0 / Math.sqrt(@right_x*@right_x + @right_y*@right_y + @right_z*@right_z)
      @right_x *= right_length
      @right_y *= right_length
      @right_z *= right_length

      # Recalculate the camera's up vector based on forward and right vectors
      @up_x = @right_y * @forward_z - @right_z * @forward_y
      @up_y = @right_z * @forward_x - @right_x * @forward_z
      @up_z = @right_x * @forward_y - @right_y * @forward_x
      up_length = 1.0 / Math.sqrt(@up_x*@up_x + @up_y*@up_y + @up_z*@up_z)
      @up_x *= up_length
      @up_y *= up_length
      @up_z *= up_length
    end

    def draw_sprite_layer_orthographic layer, ffi
      num_actors = layer.size

      i = 0
      while i < num_actors
        actor = layer[i]
        x = actor[:x]
        y = actor[:y]
        z = actor[:z]

        camera_vector_x = x - @camera_x
        camera_vector_y = y - @camera_y
        camera_vector_z = z - @camera_z

        projected_x = -(camera_vector_x * @right_x + camera_vector_y * @right_y + camera_vector_z * @right_z) * @zoom
        projected_y = (camera_vector_x * @up_x + camera_vector_y * @up_y + camera_vector_z * @up_z) * @zoom

        ffi.draw_sprite_5(projected_x,        # x
                          projected_y,        # y
                          actor[:w] * @zoom,  # w
                          actor[:h] * @zoom,  # h
                          actor[:path],       # path
                          nil,                # angle
                          nil,                # alpha
                          nil,                # red
                          nil,                # green
                          nil,                # blue
                          nil,                # tile_x
                          nil,                # tile_y
                          nil,                # tile_w
                          nil,                # tile_h
                          nil,                # flip_horizontally
                          nil,                # flip_vertically
                          nil,                # angle_anchor_x
                          nil,                # angle_anchor_y
                          nil,                # source_x
                          nil,                # source_y
                          nil,                # source_w
                          nil,                # source_h
                          nil,                # blendmode
                          0.5,                # anchor_x
                          0.5)                # anchor_y

        i += 1
      end
    end

    def draw_sprite_layer_perspective layer, ffi
      num_actors = layer.size

      i = 0
      while i < num_actors
        actor = layer[i]
        x = actor[:x]
        y = actor[:y]
        z = actor[:z]

        camera_vector_x = x - @camera_x
        camera_vector_y = y - @camera_y
        camera_vector_z = z - @camera_z

        # Compute perspective projection
        dot_product = camera_vector_x * @forward_x + camera_vector_y * @forward_y + camera_vector_z * @forward_z
        perspective_divisor = 1.0 / dot_product / @h_fov

        # Apply perspective projection
        projected_x = -(camera_vector_x * @right_x + camera_vector_y * @right_y + camera_vector_z * @right_z) * perspective_divisor
        projected_y = (camera_vector_x * @up_x + camera_vector_y * @up_y + camera_vector_z * @up_z) * perspective_divisor

        ffi.draw_sprite_5(
          projected_x,                        # x
          projected_y,                        # y
          actor[:w] * perspective_divisor,    # w
          actor[:h] * perspective_divisor,    # h
          actor[:path],                       # path
          nil,                                # angle
          nil,                                # alpha
          nil,                                # red
          nil,                                # green
          nil,                                # blue
          nil,                                # tile_x
          nil,                                # tile_y
          nil,                                # tile_w
          nil,                                # tile_h
          nil,                                # flip_horizontally
          nil,                                # flip_vertically
          nil,                                # angle_anchor_x
          nil,                                # angle_anchor_y
          nil,                                # source_x
          nil,                                # source_y
          nil,                                # source_w
          nil,                                # source_h
          nil,                                # blendmode
          0.5,                                # anchor_x
          0.5)                                # anchor_y

        i += 1
      end
    end

    def draw_sprite_layer_screen layer, ffi
      num_actors = layer.size

      i = 0
      while i < num_actors
        actor = layer[i]

        ffi.draw_sprite_5(
          actor[:x],                          # x
          actor[:y],                          # y
          actor[:w],                          # w
          actor[:h],                          # h
          actor[:path],                       # path
          nil,                                # angle
          nil,                                # alpha
          nil,                                # red
          nil,                                # green
          nil,                                # blue
          nil,                                # tile_x
          nil,                                # tile_y
          nil,                                # tile_w
          nil,                                # tile_h
          nil,                                # flip_horizontally
          nil,                                # flip_vertically
          nil,                                # angle_anchor_x
          nil,                                # angle_anchor_y
          nil,                                # source_x
          nil,                                # source_y
          nil,                                # source_w
          nil,                                # source_h
          nil,                                # blendmode
          0.5,                                # anchor_x
          0.5)                                # anchor_y

        i += 1
      end
    end

    def draw_mesh_layer_orthographic layer, ffi

    end

    def draw_mesh_layer_perspective layer, ffi
      light_dir = [0.75, 0, 0.5]
      length = Math.sqrt(light_dir[0]**2 + light_dir[1]**2 + light_dir[2]**2)
      light_dir.map! { |v| v / length }

      num_actors = layer.size

      i = 0
      while i < num_actors
        actor = layer[i]
        vertices = actor[:vertices]
        num_vertices = vertices.size / 5
        transformed_vertices = Array.new(num_vertices * 3)

        indices = actor[:indices]
        num_triangles = indices.size / 3
        z_values = Array.new(num_triangles / 3)

        j = 0
        while j < num_vertices
          vx = vertices[j * 5]
          vy = vertices[j * 5 + 1]
          vz = vertices[j * 5 + 2]

          camera_vector_x = vx - @camera_x
          camera_vector_y = vy - @camera_y
          camera_vector_z = vz - @camera_z

          # Compute perspective projection
          dot_product = (camera_vector_x * @forward_x + camera_vector_y * @forward_y + camera_vector_z * @forward_z)
          perspective_divisor = @zoom / 1.0 / (dot_product + Float::EPSILON)

          # Apply perspective projection and store transformed vertices
          transformed_vertices[j * 3] = (camera_vector_x * @right_x + camera_vector_y * @right_y + camera_vector_z * @right_z) * perspective_divisor * SCREEN_CX
          transformed_vertices[j * 3 + 1] = (camera_vector_x * @up_x + camera_vector_y * @up_y + camera_vector_z * @up_z) * perspective_divisor * SCREEN_CY
          transformed_vertices[j * 3 + 2] = perspective_divisor

          j += 1
        end

        j = 0
        while j < num_triangles
          idx1 = indices[j * 3]
          idx2 = indices[j * 3 + 1]
          idx3 = indices[j * 3 + 2]

          x1 = transformed_vertices[idx1 * 3]
          y1 = transformed_vertices[idx1 * 3 + 1]
          z1 = transformed_vertices[idx1 * 3 + 2]

          x2 = transformed_vertices[idx2 * 3]
          y2 = transformed_vertices[idx2 * 3 + 1]
          z2 = transformed_vertices[idx2 * 3 + 2]

          x3 = transformed_vertices[idx3 * 3]
          y3 = transformed_vertices[idx3 * 3 + 1]
          z3 = transformed_vertices[idx3 * 3 + 2]

          # Culling based on vertex winding
          edge1_x = x2 - x1
          edge1_y = y2 - y1
          edge2_x = x3 - x1
          edge2_y = y3 - y1
          if edge1_x * edge2_y - edge1_y * edge2_x < 0
            j += 1
            next
          end

          # Calculate surface normal
          edge1_z = z2 - z1
          edge2_z = z3 - z1
          nx = edge1_y * edge2_z - edge1_z * edge2_y
          ny = edge1_z * edge2_x - edge1_x * edge2_z
          nz = edge1_x * edge2_y - edge1_y * edge2_x
          normal_length = 1.0 / Math.sqrt(nx*nx + ny*ny + nz*nz)
          nx *= normal_length
          ny *= normal_length
          nz *= normal_length

          intensity = nx * light_dir[0] + ny * light_dir[1] + nz * light_dir[2]
          #raise 'invalid intensity' if intensity < 0 || intensity > 1
          r = (intensity * 128).to_i
          g = (intensity * 128).to_i
          b = (intensity * 255).to_i

          u1 = vertices[idx1 * 5 + 3]
          v1 = vertices[idx1 * 5 + 4]
          u2 = vertices[idx2 * 5 + 3]
          v2 = vertices[idx2 * 5 + 4]
          u3 = vertices[idx3 * 5 + 3]
          v3 = vertices[idx3 * 5 + 4]

          z_values[j] = (z1 + z2 + z3) / 3.0

          ffi.draw_triangle(
            x1,
            y1,
            x2,
            y2,
            x3,
            y3,
            r,
            g,
            b,
            255,
            actor[:path],
            u1,
            v1,
            u2,
            v2,
            u3,
            v3,
            nil)

          if @draw_wireframe
            ffi.draw_line_2(x1, y1, x2, y2, 255, 128, 255, 255, 1)
            ffi.draw_line_2(x2, y2, x3, y3, 255, 128, 255, 255, 1)
            ffi.draw_line_2(x3, y3, x1, y1, 255, 128, 255, 255, 1)
          end

          j += 1
        end

        i += 1
      end
    end

    def draw_mesh_layer_screen layer, ffi

    end
  end
end
