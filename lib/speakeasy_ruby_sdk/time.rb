module SpeakeasyRubySdk
  class TimeUtils
    ## Convenience class to optionally override times
    ## In test environment
    def initialize(start_time=nil, elapsed_time=nil)
      @start_time = start_time
      @elapsed_time = elapsed_time
      @end_time = nil
    end
    
    def start_time
      now
    end

    def now
      if @start_time.nil?
        @start_time
        @start_time = Time.now
        return @start_time
      else
        return @start_time
      end
    end

    def set_end_time
      @end_time = Time.now
    end

    def elapsed_time
      if !@elapsed_time.nil?
        return @elapsed_time
      else
        @elapsed_time = time_difference(@end_time, @start_time)
      end
    end

    def time_difference end_time, start_time
      ((end_time - start_time)).to_i
    end

  end
end