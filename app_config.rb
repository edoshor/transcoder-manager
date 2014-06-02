# Default transcoders low-level api ports
DEFAULT_PORT = 10000
DEFAULT_STATUS_PORT = 11000


# Audio controller: triggers on public or private events
# command = start | stop
AUDIO_CONTROLLER = 'http://audio1.bbdomain.org/%{command}'

# Groups controller: triggers on private events
# command = start | stop
GROUPS_CONTROLLER = 'http://10.66.1.123/v4g/index.sh?stream=%{command}'

# Streams controller: triggers on all events
# csid = event cross system ID
# command = start | stop
STREAMS_CONTROLLER='http://10.102.4.111:3001/event/%{csid}/%{command}'

# Sviva Tova controller: triggers on live private and live sadna events
# params are sent via HTTP POST, x-www-form-urlencoded
# stream_preset_id = sviva tova internal stream preset id
# state = hard coded mapping of our event state to sviva tova's states
SVIVA_TOVA_CONTROLLER='http://kabbalahgroup.info/internet/api/v1/streams/set_stream_state.json'

SVIVA_TOVA_STREAM_PRESET_IDS = {:'private' => 3, :'sadna' => 6}
SVIVA_TOVA_STATES = {on: 'active', ready: 'preparing_to_broadcast', off: 'not_active'}
