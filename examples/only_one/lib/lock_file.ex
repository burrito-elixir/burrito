defmodule OnlyOne.LockFile do
  @lock_content "BURRITO"

  def make_lock_file do
    path = Path.join(File.cwd!(), ["only_one.lock"])
    File.write!(path, @lock_content)
  end

  def delete_lock_file do
    path = Path.join(File.cwd!(), ["only_one.lock"])
    File.rm!(path)
  end
end
