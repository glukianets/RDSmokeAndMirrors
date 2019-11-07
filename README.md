# RDSmokeAndMirrors

This repo contains various tools made through hacking objc runtime. Be aware.

## Secret knowledge

### Simple types
| @encode(Type) | const char * |
|:------------|:----------:|
|`id`|@|
|`Class`|#|
|`SEL`|:|
|`char *`| * |
|`signed char`|c|
|`unsigned char`|C|
|`_Bool`|B|
|`short`|s|
|`unsigned short`|S|
|`int`|i|
|`unsigned int`|I|
|`long`|l|
|`unsigned long`|L|
|`long long`|q|
|`unsigned long long`|Q|
|`int128_t`|t|
|`int128_t`|T|
|`float`|f|
|`double`|d|
|`long double`|D|
|`void`|v|
|`Type *`|^**X**|
|`_Complex Type`|j**X**|
|`_Atomic Type`|A**X**|
|`const Type`|r**X**|
|`Type[32]`|[**X**;32]|
|`struct { Type x, y; }`|{?=**XX**}|
|`struct Name { }`|{Name=}|
|`struct { int x: 10; }`|{?=b10}|
|`union { Type x, y; }`|(?=**XX**)|
|`union Name { }`|(Name=)|
|`Type (*)(…)`|^?|
|`Type (^)(…)`|@?|
|`simd Type	`|!**X**|

### Structures

```
                              xy              wh
                              | |               | |
 {CGRect={CGPoint=dd}{CGSize=dd}}
 ╒═══ ╒═════╒═════
 ╘name  ╘origin        ╘size
```
### Method argument attributes
| attribute | encoding |
|:------------|:----------:|
|`const`|r|
|`in`|n|
|`out`|o|
|`inout`|N|
|`bycopy`|O|
|`byref`|R|
|`oneway`|V|
|`?`|?|

### Property attribute

| attribute | encoding | value |
|:------------|:----------:|:------|
|`readonly`|R||
|`copy`|C||
|`retain`|&||
|`nonatomic`|N||
|`getter=`|G|selector|
|`setter=`|S|selector|
|`@dynamic|`|D||
|`weak`|W||
|`@synthesize x = y;`|V|ivar name|
|`*legacy encoding*`|t|type encoding|
|`*garbage-collected*`|P||