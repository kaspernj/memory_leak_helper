class Memory_leak_helper
  attr_reader :objects_alive
  
  #Constructor. Spawns used hashes.
  def initialize
    @objects_alive = {}
    @objects_data = {}
  end
  
  #Registers the object in the leak-helper hash.
  def register_object(args)
    return nil if !@objects_alive
    
    obj, caller_arr = args[:obj], args[:caller]
    obj_id = obj.__id__
    
    class_name = obj.class.name
    callback_str = caller_arr.join("___")
    
    #Increase count of object-callback.
    @objects_alive[class_name] = {} if !@objects_alive.key?(class_name)
    @objects_alive[class_name][callback_str] = {:count => 0, :callback => caller_arr} if !@objects_alive[class_name].key?(callback_str)
    @objects_alive[class_name][callback_str][:count] += 1
    
    #Spawn some data to help unsetting it again.
    @objects_data[obj_id] = {:callback_str => callback_str, :class_name => class_name}
    
    ObjectSpace.define_finalizer(obj, self.method(:object_finalized))
  end
  
  #Called when an object is finalized. This helps decrease the object-count of a callback.
  def object_finalized(obj_id)
    callback_str = @objects_data[obj_id][:callback_str]
    class_name = @objects_data[obj_id][:class_name]
    @objects_data.delete(obj_id)
    
    @objects_alive[class_name][callback_str][:count] -= 1
    @objects_alive[class_name].delete(callback_str) if @objects_alive[class_name][callback_str][:count] <= 0
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