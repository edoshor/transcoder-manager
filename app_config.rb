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

