# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative 'wrapper'

require 'zlib'

module Async
	module HTTP
		module Body
			class ZStream < Wrapper
				DEFAULT_LEVEL = 7
				
				DEFLATE = -Zlib::MAX_WBITS
				GZIP =  Zlib::MAX_WBITS | 16
				
				ENCODINGS = {
					'deflate' => DEFLATE,
					'gzip' => GZIP,
				}
				
				def self.encoding_name(window_size)
					if window_size <= -8
						return 'deflate'
					elsif window_size >= 16
						return 'gzip'
					else
						return 'compress'
					end
				end
				
				def initialize(body, stream)
					super(body)
					
					@stream = stream
					
					@input_size = 0
					@output_size = 0
				end
				
				attr :input_size
				attr :output_size
				
				def ratio
					@output_size.to_f / @input_size.to_f
				end
				
				def stop(error)
					# There are two ways for the stream to be closed. Either #read returns nil or #stop is called.
					@stream.close unless @stream.closed?
					
					super
				end
				
				def inspect
					"#{super} | \#<#{self.class} #{(ratio*100).round(2)}%>"
				end
			end
			
			class Deflate < ZStream
				def self.for(body, window_size = GZIP, level = DEFAULT_LEVEL)
					self.new(body, Zlib::Deflate.new(level, window_size))
				end
				
				def read
					return if @stream.closed?
					
					if chunk = super
						@input_size += chunk.bytesize
						
						chunk = @stream.deflate(chunk, Zlib::SYNC_FLUSH)
						
						@output_size += chunk.bytesize
						
						return chunk
					else
						chunk = @stream.finish
						
						@output_size += chunk.bytesize
						
						@stream.close
						
						return chunk.empty? ? nil : chunk
					end
				end
			end
		end
	end
end