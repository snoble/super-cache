require 'sourcify'
require 'digest'


class SuperCache
  instance_methods.each do |meth|
    # skipping undef of methods that "may cause serious problems"
    undef_method(meth) if meth !~ /^(__|object_id)/
  end

  def initialize(cache, parent, method = nil, args = [], blk = nil)
    @parent = parent
    @args = args
    @blk = blk
    @evaluated = false
    @value = nil
    @method = method
    @cache = cache
  end

  def is_super_cache?
    true
  end

  def parent_is_super_cache?
    begin
      @parent.is_super_cache?
    rescue
      false
    end
  end

  def super_cache_signature
    return @signature if @signature
    sha256 = Digest::SHA256.new
    parent_signature = if parent_is_super_cache?
                         @parent.super_cache_signature
                       else
                         sha256.base64digest(@parent.to_s)
                       end
    args_signatures = @args.map do |arg|
      begin
        arg.is_super_cache? ? arg.super_cache_signature : sha256.base64digest(arg.to_s)
      rescue
        sha256.base64digest(arg.to_s)
      end
    end
    blk_signature = @blk ? sha256.base64digest(@blk.to_sexp.to_s) : nil
    @signature = sha256.base64digest({
      :parent => parent_signature,
      :args => args_signatures,
      :blk => blk_signature,
      :method => @method
    }.to_s)

  end

  def method_missing(method, *args, &blk)
    SuperCache.new(@cache, self, method, args, blk)
  end

  def _value
    if @cache.key?(super_cache_signature)
      @evaluated = true
      @value = @cache[super_cache_signature]
    end
    unless @evaluated
      parent = parent_is_super_cache? ? @parent._value: @parent
      args = @args.map {|arg| arg.instance_of?(SuperCache) ? arg._value : arg}
      @evaluated = true
      @value = if @method
                 if @blk
                   blk = @blk
                   parent.send(@method, *args, &blk)
                 else
                   parent.send(@method, *args)
                 end
               else
                 parent
               end
      @cache[super_cache_signature] = @value
    end
    return @value
  end
end


class Loader
  def initialize
    @_cache = {}
  end

  def _cache
    @_cache
  end

  def l(file)
    @outputs = []
    load file
    return formatted_outputs(file)
  end

  def formatted_outputs(file)
    lines = File.open(file).read.split("\n")
    n = 0
    output = []
    @outputs.each do |x|
      line_number = /:([0-9]*):/.match(x[:caller])[1].to_i
      (n ... line_number).each {|m| output << lines[m]}
      output << "> #{x[:output]}"
      n = line_number
    end
    (n ... lines.length).each {|m| output << lines[m]}
    output.join("\n")
  end

  def w(x)
    call_array = caller(0)
    @outputs << {:caller => call_array[-5], :output => x._value}
  end
end

@loader = Loader.new
def _cache
  @loader._cache
end
def w(*args)
  @loader.w(*args)
end
def wrap(x)
  SuperCache.new(_cache, x)
end
class BlockCaller
  def to_s
    "block_caller"
  end
  def run(&blk)
    blk.call
  end
end

def construct(&blk)
  SuperCache.new(_cache, BlockCaller.new, :run, [], blk)
end

def run_and_update
  @last_modified = File.mtime('./foo.rb')

  begin
    puts @last_modified
    puts @loader.l('./foo.rb').to_s
  rescue Exception => e
    puts e
  end
end

run_and_update
while true
  if File.mtime('./foo.rb') > @last_modified
    run_and_update
  end
  sleep 1
end

