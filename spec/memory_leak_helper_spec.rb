require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "MemoryLeakHelper" do
  it "should work" do
    require "rubygems"
    require "memory_leak_helper"
    require "knjrbfw"
    
    objs = []
    
    1.upto(100) do
      objs << String.new("Kasper Johansen")
    end
    
    found = false
    Memory_leak_helper::INSTANCE.objects_alive["String"].each do |callback_str, data|
      found = true if data[:count] == 100
    end
    
    raise "Expected a callback to have 100 alive strings." if !found
    
    1.upto(50) do
      objs.shift
    end
    
    GC.start
    some_str = "Hmm"
    GC.start
    
    found = false
    Memory_leak_helper::INSTANCE.objects_alive["String"].each do |callback_str, data|
      found = true if data[:count] == 50
    end
    
    raise "Expected a callback to have 100 alive strings." if !found
  end
end
