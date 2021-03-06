#!/home/weicc/.rbenv/shims/ruby
# encoding: utf-8
require 'rainbow/ext/string'
class Depend
  attr_reader :hash, :dirs, :lib, :inc, :flags

  def initialize(hash, order = nil, flags = nil)
    @dirs, @lib, @inc = [], [], []
    @hash = {}
    @order = order
    @flags = flags
    @ext_inc_to_s = ''
    @ext_lib_to_s = ''
    append(hash, @order)
  end

  def append(hash, order = nil)
    hash = expand_path(hash)

    @hash.merge!(hash)
    readhash(hash)

    sort(order || @order)
    @inc_to_s = @inc.map { |dir| "-I#{dir}" }.join(' ')
  end

  def sort(order)
    path, lib = @lib.transpose
    path.map! { |dir| "-L#{dir}" }
    @lib_to_s = (path + sort_vec(lib.flatten, order)).join(' ')
  end

  def inc_to_s
    @inc_to_s + ' ' + @ext_inc_to_s
  end

  def lib_to_s
    [@lib_to_s, @ext_lib_to_s, rpath].join(' ')
  end

  def rpath
    result = [@lib_to_s, @ext_lib_to_s].join(' ').split(' ')
    .select { |t| t.start_with?('-L') }.map { |t| ['-rpath', t.sub('-L', '')] }

    result.unshift('-Wl').join(',')
  end

  def addinc(exinc)
    @ext_inc_to_s = @ext_inc_to_s + ' ' + exinc.join(' ')
  end

  def addlib(exlib)
    @ext_lib_to_s = @ext_lib_to_s + ' ' + exlib.join(' ')
  end

  private

  def expand_path(hash)
    hash.each.map { |path, val| [path && File.expand_path(path), val] }.to_h
  end

  def readhash(hash, base = nil)
    return unless hash.is_a?(Hash)
    bs = ->(key) { [base, key].compact.join('/') }

    hash.each do |k, v|
      v.is_a?(Array) ? record(bs.call(k), v) : readhash(v, bs.call(k))
    end
  end

  def sort_vec(vector, order)
    return vector unless order
    orderl = order.map { |x| "-l#{x}" }
    orderl + (vector - orderl)
  end

  def unexist?(x)
    return true if @lib.empty?
    @lib.transpose[1].flatten.include?("-l#{x}") ? nil : true
  end

  def record(path, libs)
    libs.empty? ? record_empty(path) : record_libs(path, libs)
  end

  def record_empty(path)
    add_to_list(@inc, "#{path}", 'include')
  end

  def record_libs(path, libs)
    @dirs << path
    lbs = ["#{path}/lib", libs.map { |x| "-l#{x}" if unexist?(x) }.compact]
    add_to_list(@lib, lbs, 'library')
    add_to_list(@inc, "#{path}/include", 'include')
  end

  EXCLUDELIST = %w(/include)
  def add_to_list(list, term, kind)
    return if EXCLUDELIST.include?(term)
    list << term
    path = term.is_a?(String) ? term : term[0]
    test_path(path, kind)
  end

  def test_path(path, info = nil)
    sentence = "The #{info + ' ' if info}path #{path.bright} unexist"
    raise sentence unless File.exist?(path)
  end
end
