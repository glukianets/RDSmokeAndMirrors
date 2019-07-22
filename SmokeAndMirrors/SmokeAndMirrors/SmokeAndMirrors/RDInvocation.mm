#import "RDInvocation.h"
#import "RDPrivate.h"
#import <ffi/ffi.h>

NSErrorDomain const RDInvocationErrorDomain = @"RDInvocationErrorDomain";
NSInteger const RDInvocationFFIErrorCode = 257;
NSInteger const RDInvocationMethodResolutionErrorCode = 258;
NSInteger const RDInvocationMethodTypeSafetyErrorCode = 259;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define RDFFIError(STATUS) [NSError errorWithDomain:RDInvocationErrorDomain code:RDInvocationFFIErrorCode userInfo:@{ @"ffi_prep_cif": @(STATUS) }]
#define RDMethodResulutionError() [NSError errorWithDomain:RDInvocationErrorDomain code:RDInvocationMethodResolutionErrorCode userInfo:nil]
#define RDMethodTypeSafetyError() [NSError errorWithDomain:RDInvocationErrorDomain code:RDInvocationMethodTypeSafetyErrorCode userInfo:nil]

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDType(RDInvocation)

- (ffi_type *_Nullable)_inv_ffi_type;
+ (void)_inv_ffi_type_destroy:(ffi_type *)type;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@interface RDInvocation()

@property (nonatomic, readonly) ffi_cif cif;
@property (nonatomic, readonly) NSUInteger argCount;
@property (nonatomic, readonly) ffi_type **argTypes;
@property (nonatomic, readonly) void **argValues;

@end

@implementation RDInvocation

+ (instancetype)invocationWithArguments:(RDValue *)arguments {
    return [[self alloc] initWithArguments:arguments];
}

- (void)dealloc {
    for (NSUInteger i = 0; i < _argCount; ++i)
        [RDType _inv_ffi_type_destroy:_argTypes[i]];

    free(_argTypes);
    free(_argValues);
}

- (instancetype)initWithArguments:(RDValue *)arguments {
    if (arguments == nil)
        return nil;
    
    self = [super init];
    if (self) {
        _arguments = arguments.copy;
        
        NSUInteger count;
        if (RDAggregateType *type = RD_CAST(arguments.type, RDAggregateType); type != nil) {
            if (type.kind != RDAggregateTypeKindStruct)
                return nil;
            count = type.count;
        } else if (RDArrayType *type = RD_CAST(arguments.type, RDArrayType); type != nil) {
            count = type.count;
        } else {
            return nil;
        }

        _argCount = count + 2;
        _argTypes = (ffi_type **)calloc(count, sizeof(ffi_type *));
        _argValues = (void **)calloc(count, sizeof(void *));

        _argTypes[0] = &ffi_type_pointer; // self
        _argTypes[1] = &ffi_type_pointer; // _cmd
        for (NSUInteger i = 0; i < count; ++i) {
            RDType *fieldType = nil;
            _argValues[i + 2] = (void *)[arguments bufferAtIndex:i type:&fieldType];
            _argTypes[i + 2] = fieldType._inv_ffi_type;
        }
    }
    return self;
}

- (RDValue *)invokeWithTarget:(id<NSObject>)target selector:(SEL)selector {
    NSError *error = nil;
    RDValue *result = [self invokeWithTarget:target selector:selector error:&error];
    if (error != nil)
        @throw [[NSException alloc] initWithName:@"InvocationFailedException"
                                          reason:@"invoke returned non-zero error"
                                        userInfo:@{ NSUnderlyingErrorKey: error }];
    return result;
}

- (RDValue *)invokeWithTarget:(id<NSObject>)target selector:(SEL)selector error:(NSError **)error {
    if (target == nil)
        return (void)(error != NULL && (*error = nil)), nil;
    
    Method method = class_getInstanceMethod(object_getClass(target), selector);
    if (method == NULL)
        return (void)(error != NULL && (*error = RDMethodResulutionError())), nil;

    RDMethodSignature *sig = [RDMethodSignature signatureWithObjcTypeEncoding:method_getTypeEncoding(method)];
    if (sig == nil)
        return (void)(error != NULL && (*error = RDMethodTypeSafetyError())), nil;

    RDType *retType = sig.returnValue.type;
    if (retType == nil)
        return (void)(error != NULL && (*error = RDMethodTypeSafetyError())), nil;

    ffi_type *retFFIType = retType._inv_ffi_type;
    if (retFFIType == NULL)
        return (void)(error != NULL && (*error = RDMethodTypeSafetyError())), nil;
    RD_DEFER { [RDType _inv_ffi_type_destroy:retFFIType]; };

    if (ffi_status status = ffi_prep_cif(&_cif, FFI_DEFAULT_ABI, (unsigned)_argCount, retFFIType, _argTypes); status != FFI_OK)
        return (void)(error != NULL && (*error = RDFFIError(status))), nil;

    _argValues[0] = &target;
    _argValues[1] = &selector;
    RDMutableValue *retValue = [RDMutableValue valueWithBytes:nil ofType:retType];
    ffi_call(&_cif, method_getImplementation(method), [retValue bufferType:NULL], _argValues);
    
    return (void)(error != NULL && (*error = nil)), retValue;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation RDType(RDInvocation)

- (ffi_type *)_inv_ffi_type {
    return NULL;
}

+ (void)_inv_ffi_type_destroy:(ffi_type *)type {
    if (type == NULL || type->type != FFI_TYPE_STRUCT)
        return;
    
    ffi_type **elements = (ffi_type **)(type + 1);
    while (*elements++ != NULL)
        [self _inv_ffi_type_destroy:*elements];
    
    free(type);
}

@end


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDUnknownType(RDInvocation)
@end

@implementation RDUnknownType(RDInvocation)
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDVoidType(RDInvocation)
@end

@implementation RDVoidType(RDInvocation)

- (ffi_type *)_inv_ffi_type {
    return &ffi_type_void;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDObjectType(RDInvocation)
@end

@implementation RDObjectType(RDInvocation)

- (ffi_type *)_inv_ffi_type {
    return &ffi_type_pointer;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDBlockType(RDInvocation)
@end

@implementation RDBlockType(RDInvocation)

- (ffi_type *)_inv_ffi_type {
    return &ffi_type_pointer;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDPrimitiveType(RDInvocation)
@end

@implementation RDPrimitiveType(RDInvocation)

- (ffi_type *)_inv_ffi_type {
    switch (self.kind) {
        case RDPrimitiveTypeKindClass:
        case RDPrimitiveTypeKindSelector:
        case RDPrimitiveTypeKindCString:
        case RDPrimitiveTypeKindAtom:
            return &ffi_type_pointer;

        case RDPrimitiveTypeKindChar:
            return &ffi_type_schar;

        case RDPrimitiveTypeKindUnsignedChar:
            return &ffi_type_uchar;

        case RDPrimitiveTypeKindBool:
            return NULL; //TODO: find closest bool representation

        case RDPrimitiveTypeKindShort:
            return &ffi_type_sshort;

        case RDPrimitiveTypeKindUnsignedShort:
            return &ffi_type_ushort;

        case RDPrimitiveTypeKindInt:
            return &ffi_type_sint;

        case RDPrimitiveTypeKindUnsignedInt:
            return &ffi_type_uint;

        case RDPrimitiveTypeKindLong:
            return &ffi_type_slong;

        case RDPrimitiveTypeKindUnsignedLong:
            return &ffi_type_ulong;

        case RDPrimitiveTypeKindLongLong:
            return &ffi_type_slong;

        case RDPrimitiveTypeKindUnsignedLongLong:
            return &ffi_type_ulong;

        case RDPrimitiveTypeKindInt128:
            return NULL;

        case RDPrimitiveTypeKindUnsignedInt128:
            return NULL;

        case RDPrimitiveTypeKindFloat:
            return &ffi_type_float;

        case RDPrimitiveTypeKindDouble:
            return &ffi_type_double;

        case RDPrimitiveTypeKindLongDouble:
            return &ffi_type_longdouble;
    }
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDCompositeType(RDInvocation)
@end

@implementation RDCompositeType(RDInvocation)

- (ffi_type *)_inv_ffi_type {
    switch (self.kind) {
        case RDCompositeTypeKindPointer:
            return &ffi_type_pointer;

        case RDCompositeTypeKindVector:
            return NULL;

        case RDCompositeTypeKindComplex:
            if (RDPrimitiveType *type = RD_CAST(self.type, RDPrimitiveType); type != nil)
                switch (type.kind) {
                    case RDPrimitiveTypeKindFloat:
                        return &ffi_type_complex_float;
                    case RDPrimitiveTypeKindDouble:
                        return &ffi_type_complex_double;
                    case RDPrimitiveTypeKindLongDouble:
                        return &ffi_type_complex_longdouble;
                    default:
                        return NULL;
                }
            else
                return NULL;
            
        case RDCompositeTypeKindAtomic:
            return NULL;

        case RDCompositeTypeKindConst:
            return self.type._inv_ffi_type;
    }
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDBitfieldType(RDInvocation)
@end

@implementation RDBitfieldType(RDInvocation)
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDArrayType(RDInvocation)
@end

@implementation RDArrayType(RDInvocation)

- (ffi_type *)_inv_ffi_type {
    return &ffi_type_pointer;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDAggregateType(RDInvocation)
@end

@implementation RDAggregateType(RDInvocation)

- (ffi_type *)_inv_ffi_type {
    switch (self.kind) {
        case RDAggregateTypeKindUnion:
            return NULL;
        case RDAggregateTypeKindStruct:
            ffi_type *types = (ffi_type *)calloc(1, sizeof(ffi_type) + sizeof(ffi_type *) * self.count + 1);
            types->type = FFI_TYPE_STRUCT;
            types->size = 0;
            types->alignment = 0;
            types->elements = (ffi_type **)(types + 1);
            
            for (NSUInteger i = 0; i < self.count; ++i)
                if (RDField *field = [self fieldAtIndex:i]; field != NULL)
                    types->elements[i] = field->type._inv_ffi_type;
            
            types->elements[self.count] = NULL;
            
            return types;
    }
}

@end
