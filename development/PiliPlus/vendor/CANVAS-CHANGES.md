Local snapshot of cached_network_image_ce from the already installed git revision b1597d6d58ad3bc5bcf2d93022bc893add7ce66b. Upstream license files are preserved in each package. The app overrides only these two packages locally.

DefaultCacheManager changes: mutable capacity plus setCapacity guard; quota cleanup after successful writes; FIFO-like eviction until within quota; putFile metadata preserves the leading extension dot so files can be read and removed correctly. No shared SDK package was edited.

Regression coverage: test/canvas_v8_test.dart, runnable without unrelated native hooks through qa/ui_harness. The remaining source is copied unchanged.
