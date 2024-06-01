pub fn SliceIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        inner: []T,
        i: usize = 0,

        pub fn next(self: *Self) ?T {
            const result = self.peek();
            self.i += 1;
            return result;
        }
        
        pub fn peek(self: *Self) ?T {
            if(self.i < self.inner.len) {
                return self.inner[self.i];
            } else {
                return null;
            }
        }

        pub fn hasNext(self: *Self) bool {
            return self.i < self.inner.len;
        }

    };
}