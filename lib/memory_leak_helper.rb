require "monitor"

class Memory_leak_helper
  attr_reader :objects_alive
  
  #Constructor. Spawns used hashes.
  def initialize
    @objects_alive = {}
    @objects_data = {}
    @mutex = Monitor.new
  end
  
  #Registers the object in the leak-helper hash.
  def register_object(args)
    @mutex.synchronize do
      return nil if !@objects_alive
      
      obj, backtrace_arr = args[:obj], args[:caller]
      obj_id = obj.__id__
      
      class_name = obj.class.name
      backtrace_str = backtrace_arr.join("___")
      
      #Increase count of object-callback.
      @objects_alive[class_name] = {} if !@objects_alive.key?(class_name)
      @objects_alive[class_name][backtrace_str] = {:count => 0, :backtrace => backtrace_arr} if !@objects_alive[class_name].key?(backtrace_str)
      @objects_alive[class_name][backtrace_str][:count] += 1
      
      #Spawn some data to help unsetting it again.
      @objects_data[obj_id] = {:backtrace_str => backtrace_str, :class_name => class_name}
      
      ObjectSpace.define_finalizer(obj, self.method(:object_finalized))
    end
  end
  
  #Called when an object is finalized. This helps decrease the object-count of a callback.
  def object_finalized(obj_id)
    @mutex.synchronize do
      return nil if !@objects_data.key?(obj_id)
      
      backtrace_str = @objects_data[obj_id][:backtrace_str]
      class_name = @objects_data[obj_id][:class_name]
      @objects_data.delete(obj_id)
      
      @objects_alive[class_name][backtrace_str][:count] -= 1
      @objects_alive[class_name].delete(backtrace_str) if @objects_alive[class_name][backtrace_str][:count] <= 0
    end
  end
  
  #Returns an array of possible leaks.
  def possible_leaks(args = nil)
    if args and args[:minimum]
      minimum = args[:minimum]
    else
      minimum = 40
    end
    
    @mutex.synchronize do
      leaks = []
      @objects_alive.clone.each do |class_name, backtrace_strs|
        backtrace_strs.each do |backtrace_str, data|
          if data[:count] >= minimum
            leaks << {
              :classname => class_name,
              :backtrace => data[:backtrace],
              :count => data[:count]
            }
          end
        end
      end
      
      leaks.sort! do |ele1, ele2|
        ele2[:count] <=> ele1[:count]
      end
      
      return leaks
    end
  end
  
  #Only one instance is needed. Define that as a constant.
  INSTANCE = Memory_leak_helper.new
end

#Hack the 'Class'-class in order to get callbacks when objects are created.
class ::Class
  #Alias the original new-method to a method that hopefully will never be found.
  alias __memory_leak_helper_original_new new
  
  #Make a new method that will be called whenever an object is created. Register that object with 'Memory_leak_helper' and return it as it normally would.
  def new(*args, &blk)
    mlh = Memory_leak_helper::INSTANCE
    obj = __memory_leak_helper_original_new(*args, &blk)
    mlh.register_object(:obj => obj, :caller => caller) if mlh
    
    return obj
  end
end