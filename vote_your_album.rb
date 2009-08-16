%w[rubygems sinatra json haml librmpd dm-core].each { |lib| require lib }
%w[models/album models/song models/nomination models/vote].each { |model| require model }
require 'lib/mpd_proxy'

require 'config'

# -----------------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------------
def execute_on_nomination(id, &block)
  nomination = Nomination.get(id.to_i)
  yield(nomination) if nomination
  render_upcoming
end

def json_status
  { :playing => MpdProxy.playing?, :volume => MpdProxy.volume, :current => Album.current.to_s }.to_json
end

def render_upcoming
  @nominations = Nomination.all
  haml :_upcoming, :layout => false
end

helpers do
  def score_class(score); score > 0 ? "positive" : (score < 0 ? "negative" : "") end
end


# -----------------------------------------------------------------------------------
# Actions
# -----------------------------------------------------------------------------------
get "/" do
  haml :index
end
get "/list" do
  @albums = Album.all
  haml :_list, :layout => false
end
get "/search" do
  @albums = Album.search(params[:q])
  haml :_list, :layout => false
end
get "/upcoming" do
  render_upcoming
end

get "/status" do
  json_status
end

post "/add/:id" do |album_id|
  album = Album.get(album_id.to_i)
  album.nominations.create(:status => "active", :created_at => Time.now, :nominated_by => request.ip) if album
  render_upcoming
end
post "/up/:id" do |nomination_id|
  execute_on_nomination(nomination_id) { |nomination| nomination.vote 1, request.ip }
end
post "/down/:id" do |nomination_id|
  execute_on_nomination(nomination_id) { |nomination| nomination.vote -1, request.ip }
end
post "/force" do
  # Library.force request.ip
  json_status
end

post "/control/:action" do |action|
  MpdProxy.execute action.to_sym
  json_status
end
post "/volume/:value" do |value|
  MpdProxy.change_volume_to value.to_i
end
post "/play" do
  MpdProxy.play_next unless MpdProxy.playing?
  json_status
end