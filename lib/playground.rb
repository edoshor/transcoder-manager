require 'date'

class MyBase
  fields = []

  def self.say_hi
    puts "#{hi} #{get_time}"
  end

  def self.get_time
    DateTime.now
  end

  def self.f1(fields)
    define_singleton_method :required_params do
      fields
    end
  end

  def self.f2(fields)
    define_method :f23 do
      fields
    end
  end

end

class A < MyBase
  f1 %w(I love ruby)
  f2 %w(I love ruby)

  def self.hi
    puts 'hello'
  end
end

class B < MyBase
  def self.hi
    puts 'shalom'
  end

  def self.get_time
    1
  end
end

#puts A.required_params
#puts A.new.f23

MyBase.fields


#A.say_hi
#B.say_hi

