#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

#define RD_FINAL_CLASS __attribute__((objc_subclassing_restricted))

#define RD_RETURNS_RETAINED __attribute__((ns_returns_retained))
#define RD_RETURNS_UNRETAINED __attribute__((ns_returns_not_retained))
#define RD_RETURNS_AUTORELEASED __attribute__((ns_returns_autoreleased))

#define RD_MACRO_EMPTY()
#define RD_MACRO_DEFER(id) id RD_MACRO_EMPTY()
#define RD_MACRO_OBSTRUCT(...) __VA_ARGS__ RD_MACRO_DEFER(EMPTY)()
#define RD_MACRO_EXPAND(...) __VA_ARGS__

#define RD_MACRO_STRINGIZE(arg)  _RD_MACRO_STRINGIZE1(arg)
#define _RD_MACRO_STRINGIZE1(arg) _RD_MACRO_STRINGIZE2(arg)
#define _RD_MACRO_STRINGIZE2(arg) #arg

#define RD_MACRO_CONCATENATE(arg1, arg2)   _RD_MACRO_CONCATENATE1(arg1, arg2)
#define _RD_MACRO_CONCATENATE1(arg1, arg2)  _RD_MACRO_CONCATENATE2(arg1, arg2)
#define _RD_MACRO_CONCATENATE2(arg1, arg2)  arg1##arg2

#define RD_MACRO_ARG_COUNT(...) _RD_MACRO_ARG_COUNT_(, ##__VA_ARGS__, _RD_MACRO_RSEQ_N())
#define RD_MACRO_ARG_COUNT_ZOM(...) _RD_MACRO_ARG_COUNT_(, ##__VA_ARGS__, _RD_MACRO_2RSEQ_N())
#define _RD_MACRO_ARG_COUNT_(...) _RD_MACRO_ARG_N(__VA_ARGS__)
#define _RD_MACRO_ARG_N(_0,_1,_2,_3,_4,_5,_6,_7,_8,_9,_A,_B,_C,_D,_E,_F, N, ...) N
#define _RD_MACRO_RSEQ_N()  F, E, D, C, B, A, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, _
#define _RD_MACRO_2RSEQ_N() MANY, MANY, MANY, MANY, MANY, MANY, MANY, MANY, MANY, MANY, MANY, MANY, MANY, MANY, ONE, ZERO, _

#define _RD_ALL_OF_0(MACRO, X, ...)
#define _RD_ALL_OF_1(MACRO, X, ...) MACRO(X)
#define _RD_ALL_OF_2(MACRO, X, ...) MACRO(X) && _RD_ALL_OF_1(MACRO, __VA_ARGS__)
#define _RD_ALL_OF_3(MACRO, X, ...) MACRO(X) && _RD_ALL_OF_2(MACRO, __VA_ARGS__)
#define _RD_ALL_OF_4(MACRO, X, ...) MACRO(X) && _RD_ALL_OF_3(MACRO, __VA_ARGS__)
#define _RD_ALL_OF_5(MACRO, X, ...) MACRO(X) && _RD_ALL_OF_4(MACRO, __VA_ARGS__)
#define _RD_ALL_OF_6(MACRO, X, ...) MACRO(X) && _RD_ALL_OF_5(MACRO, __VA_ARGS__)
#define _RD_ALL_OF_7(MACRO, X, ...) MACRO(X) && _RD_ALL_OF_6(MACRO, __VA_ARGS__)
#define _RD_ALL_OF_8(MACRO, X, ...) MACRO(X) && _RD_ALL_OF_7(MACRO, __VA_ARGS__)
#define _RD_ALL_OF_9(MACRO, X, ...) MACRO(X) && _RD_ALL_OF_8(MACRO, __VA_ARGS__)
#define _RD_ALL_OF_A(MACRO, X, ...) MACRO(X) && _RD_ALL_OF_9(MACRO, __VA_ARGS__)
#define _RD_ALL_OF_B(MACRO, X, ...) MACRO(X) && _RD_ALL_OF_A(MACRO, __VA_ARGS__)
#define _RD_ALL_OF_C(MACRO, X, ...) MACRO(X) && _RD_ALL_OF_B(MACRO, __VA_ARGS__)
#define _RD_ALL_OF_D(MACRO, X, ...) MACRO(X) && _RD_ALL_OF_C(MACRO, __VA_ARGS__)
#define _RD_ALL_OF_E(MACRO, X, ...) MACRO(X) && _RD_ALL_OF_D(MACRO, __VA_ARGS__)
#define _RD_ALL_OF_F(MACRO, X, ...) MACRO(X) && _RD_ALL_OF_E(MACRO, __VA_ARGS__)

#define _RD_ALL_OF_(N, MACRO, ...) RD_MACRO_CONCATENATE(_RD_ALL_OF_, N)(MACRO, __VA_ARGS__)
#define _RD_ALL_OF(MACRO, ...) _RD_ALL_OF_(RD_MACRO_ARG_COUNT(__VA_ARGS__), MACRO, __VA_ARGS__)

#define _RD_CONFORMSTOPROTOCOL(PROTO) [obj conformsToProtocol: @protocol(PROTO)]
#define _RD_CAST_MANY(OBJ, CLS, ...) (CLS<__VA_ARGS__> *)({ id obj = (OBJ); (([obj isKindOfClass: CLS.self] && _RD_ALL_OF(_RD_CONFORMSTOPROTOCOL, __VA_ARGS__)) ? obj : nil); })
#define _RD_CAST_ONE(OBJ, CLS) (CLS *)({ id obj = (OBJ); [obj isKindOfClass: CLS.self] ? obj : nil; })
#define _RD_CAST_ZERO(OBJ) (id)({ id obj = (OBJ); obj; })

#define _RD_CAST_(N, OBJ, ...) RD_MACRO_CONCATENATE(_RD_CAST_, N)(OBJ, ##__VA_ARGS__)
#define RD_CAST(OBJ, ...) _RD_CAST_(RD_MACRO_ARG_COUNT_ZOM(__VA_ARGS__), OBJ, ##__VA_ARGS__)


#define RD_FLEX_ARRAY_RAW_CREATE(CLS, SIZE, ALIGN, COUNT) class_createInstance(CLS, (ALIGN - (alignof(max_align_t) + class_getInstanceSize(CLS)) % ALIGN) % ALIGN + COUNT * SIZE)
#define RD_FLEX_ARRAY_RAW_ELEMENT(OBJ, SIZE, ALIGN, INDEX) ({ \
    __auto_type _obj = (OBJ); __auto_type _index = (INDEX); __auto_type _align = (ALIGN); __auto_type _size = (SIZE); \
    uintptr_t _base = (uintptr_t)_obj + class_getInstanceSize(object_getClass(_obj)); \
    (void *)(_base + (_align - _base % _align) % _align + _index * _size); \
})

#define RD_FLEX_ARRAY_CREATE(CLS, TYPE, COUNT) RD_FLEX_ARRAY_RAW_CREATE(CLS, sizeof(TYPE), alignof(TYPE), COUNT)
#define RD_FLEX_ARRAY_ELEMENT(OBJ, TYPE, INDEX) (TYPE *)RD_FLEX_ARRAY_RAW_ELEMENT(OBJ, sizeof(TYPE), alignof(TYPE), INDEX)

NS_ASSUME_NONNULL_END
