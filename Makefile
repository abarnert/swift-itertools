main: main.swift itertools.swift
	xcrun swift $(CFLAGS) $(LDFLAGS) $^

# Modules basically don't work yet. https://devforums.apple.com/message/976286
#main: main.swift itertools.swiftmodule
#
#%: %.swift
#	xcrun swift $(CFLAGS) $(LDFLAGS) $<
#
#%.swiftmodule: %.swift
#	xcrun swift -emit-module $(CFLAGS) $(LDFLAGS) $<
