#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <algorithm>
#include <numeric>

NS_ASSUME_NONNULL_BEGIN

template<typename T, typename U>
NSArray<U *> *_Nullable map_nn(NSArray<T *> *_Nullable source, U *_Nullable (^_Nonnull block)(T *_Nonnull)) {
    if (source == nil)
        return nil;
    
    NSMutableArray<U *> *result = [NSMutableArray arrayWithCapacity:source.count];
    for (T *obj in source)
        if (U *res = block(obj); res)
            [result addObject:res];
    
    return result;
}

template<typename R, typename ... T>
NSArray<R *> *_Nonnull zip(R *_Nullable (^_Nonnull zipper)(T *_Nonnull...), NSArray<T *> *_Nullable... args) {
    NSMutableArray<R *> *result = [NSMutableArray array];
    for (NSUInteger i = 0; i < std::min(args.count...); ++i)
        if (R *object = zipper(args[i]...); object)
            [result addObject:object];
    
    return result;
}

NS_ASSUME_NONNULL_END
