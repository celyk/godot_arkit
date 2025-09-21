## Build instructions

1. Clone the repo
2. `git submodule update --init --recursive`
3. `scons platform=ios ios_simulator=false arch=arm64 target=template_debug symbols_visibility=visible`
