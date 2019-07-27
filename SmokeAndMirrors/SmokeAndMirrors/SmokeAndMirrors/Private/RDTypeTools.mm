#import "RDTypeTools.h"

#import "RDPrivate.h"

@implementation RDType(RDPrivate)

- (void)_value_retainBytes:(void *_Nonnull)bytes {
    // Do nothing for non-retainable types by default
}

- (void)_value_releaseBytes:(void *_Nonnull)bytes {
    // Do nothing for non-retainable types by default
}

- (NSString *)_value_describeBytes:(void *)bytes additionalInfo:(NSMutableArray<NSString *> *)info {
    return nil;
}

- (NSString *)_value_formatWithBytes:(void *)bytes {
    NSMutableArray *more = [NSMutableArray array];
    NSString *desc = [self _value_describeBytes:bytes additionalInfo:more];
    NSString *decl = self.format;
    return [NSString stringWithFormat:@"%@ = %@;\n%@", decl, desc, [more componentsJoinedByString:@"\n\n"]];
}

- (ffi_type *)_ffi_type {
    return NULL;
}

+ (void)_ffi_type_destroy:(ffi_type *)type {
    if (type == NULL || type->type != FFI_TYPE_STRUCT)
        return;
    
    ffi_type **elements = (ffi_type **)(type + 1);
    while (*elements++ != NULL)
        [self _ffi_type_destroy:*elements];
    
    free(type);
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDUnknownType(RDPrivate)
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDObjectType(RDPrivate)
@end

@implementation RDObjectType(RDPrivate)

- (void)_value_retainBytes:(void *_Nonnull)bytes {
    switch (self.kind) {
    case RDObjectTypeKindGeneric:
        *(void **)bytes = (__bridge void *)objc_retain((__bridge id)*(void **)bytes);
        break;
    case RDObjectTypeKindBlock:
        *(void **)bytes = (__bridge void *)objc_retainBlock((__bridge id)*(void **)bytes);
        break;
    case RDObjectTypeKindClass:
        //do nothing
        break;
    }
}

- (void)_value_releaseBytes:(void *_Nonnull)bytes {
    switch (self.kind) {
    case RDObjectTypeKindGeneric:
    case RDObjectTypeKindBlock:
        objc_release((__bridge id)*(void **)bytes);
        break;
    case RDObjectTypeKindClass:
        //do nothing
        break;
    }

}

- (NSString *)_value_describeBytes:(void *)bytes additionalInfo:(NSMutableArray<NSString *> *)info {
    if (NSString *description = [(__bridge id)*(void **)bytes description]; description != nil)
        [info addObject:[NSString stringWithFormat:@"Printing description of (%@)%p:\n%@", self.description, *(void **)bytes, description]];

    if (void *ptr = *(void **)bytes; ptr != NULL)
        switch (self.kind) {
        case RDObjectTypeKindGeneric:
        case RDObjectTypeKindBlock:
            return [NSString stringWithFormat:@"(%@)%p", self.description, ptr];
        case RDObjectTypeKindClass:
            return [NSString stringWithFormat:@"%@.self", NSStringFromClass(*(Class *)bytes)];
        }
    else
        return @"nil";
}

- (ffi_type *)_ffi_type {
    return &ffi_type_pointer;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDVoidType(RDPrivate)
@end

@implementation RDVoidType(RDPrivate)

- (NSString *)_value_describeBytes:(void *)bytes additionalInfo:(NSMutableArray<NSString *> *)info {
    return @"void";
}

- (ffi_type *)_ffi_type {
    return &ffi_type_void;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDPrimitiveType(RDPrivate)
@end

@implementation RDPrimitiveType(RDPrivate)

- (NSString *)_value_describeBytes:(void *)bytes additionalInfo:(NSMutableArray<NSString *> *)info {
    switch (self.kind) {
        case RDPrimitiveTypeKindSelector:
            return [NSString stringWithFormat:@"@selector(%s)", sel_getName(*(SEL *)bytes)];
        case RDPrimitiveTypeKindCString:
            return [NSString stringWithFormat:@"c string at \"%p\"", *(const char **)bytes];
        case RDPrimitiveTypeKindAtom:
            return [NSString stringWithFormat:@"?"];
        case RDPrimitiveTypeKindChar:
            return [NSString stringWithFormat:@"'%c'", *(char *)bytes];
        case RDPrimitiveTypeKindUnsignedChar:
            return [NSString stringWithFormat:@"(unsigned char)'%c'", *(unsigned char *)bytes];
        case RDPrimitiveTypeKindBool:
            return [NSString stringWithFormat:@"%s", *(unsigned char *)bytes ? "true" : "false"];
        case RDPrimitiveTypeKindShort:
            return [NSString stringWithFormat:@"(short)%d", *(short *)bytes];
        case RDPrimitiveTypeKindUnsignedShort:
            return [NSString stringWithFormat:@"(unsigned short)%du", *(unsigned short *)bytes];
        case RDPrimitiveTypeKindInt:
            return [NSString stringWithFormat:@"%d", *(int *)bytes];
        case RDPrimitiveTypeKindUnsignedInt:
            return [NSString stringWithFormat:@"%du", *(unsigned int *)bytes];
        case RDPrimitiveTypeKindLong:
            return [NSString stringWithFormat:@"%ldl", *(long *)bytes];
        case RDPrimitiveTypeKindUnsignedLong:
            return [NSString stringWithFormat:@"%luul", *(unsigned long *)bytes];
        case RDPrimitiveTypeKindLongLong:
            return [NSString stringWithFormat:@"%lldll", *(long long int *)bytes];
        case RDPrimitiveTypeKindUnsignedLongLong:
            return [NSString stringWithFormat:@"%lluull", *(unsigned long long *)bytes];
        case RDPrimitiveTypeKindInt128:
            return [NSString stringWithFormat:@"(int128_t)%lld", (long long)*(__int128_t *)bytes];
        case RDPrimitiveTypeKindUnsignedInt128:
            return [NSString stringWithFormat:@"(uint128_t)%llu", (unsigned long long)*(__uint128_t *)bytes];
        case RDPrimitiveTypeKindFloat:
            return [NSString stringWithFormat:@"%ff", *(float *)bytes];
        case RDPrimitiveTypeKindDouble:
            return [NSString stringWithFormat:@"%f", *(double *)bytes];
        case RDPrimitiveTypeKindLongDouble:
            return [NSString stringWithFormat:@"%Lfl", *(long double *)bytes];
    }
    return nil;
}

- (ffi_type *)_ffi_type {
    static ffi_type *const boolType = ({
        #if OBJC_BOOL_IS_BOOL
                // this is what RubyCocoa seeem to be picking for regular bool
                &ffi_type_uchar;
        #else
                // BOOL is defined to be explicitly signed char in this case
                &ffi_type_schar;
        #endif
    });
    
    switch (self.kind) {
        case RDPrimitiveTypeKindSelector:
        case RDPrimitiveTypeKindCString:
        case RDPrimitiveTypeKindAtom:
            return &ffi_type_pointer;
        case RDPrimitiveTypeKindChar:
            return &ffi_type_schar;
        case RDPrimitiveTypeKindUnsignedChar:
            return &ffi_type_uchar;
        case RDPrimitiveTypeKindBool:
            return boolType;
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

@interface RDCompositeType(RDPrivate)
@end

@implementation RDCompositeType(RDPrivate)

- (NSString *)_value_describeBytes:(void *)bytes additionalInfo:(NSMutableArray<NSString *> *)info {
    return [self.type _value_describeBytes:bytes additionalInfo:info];
}

- (ffi_type *)_ffi_type {
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
            return self.type._ffi_type;
    }
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDBitfieldType(RDPrivate)
@end

@implementation RDBitfieldType(RDPrivate)
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDArrayType(RDPrivate)
@end

@implementation RDArrayType(RDPrivate)

- (void)_value_retainBytes:(void *)bytes {
    if (bytes != NULL)
        for (NSUInteger i = 0; i < self.count; ++i)
            if (size_t offset = [self offsetForElementAtIndex:i]; offset != RDOffsetUnknown)
                [self.type _value_retainBytes:(uint8_t *)bytes + offset];
}

- (void)_value_releaseBytes:(void *)bytes {
    if (bytes != NULL)
        for (NSUInteger i = 0; i < self.count; ++i)
            if (size_t offset = [self offsetForElementAtIndex:i]; offset != RDOffsetUnknown)
                [self.type _value_releaseBytes:(uint8_t *)bytes + offset];
}

- (NSString *)_value_describeBytes:(void *)bytes additionalInfo:(NSMutableArray<NSString *> *)info {
    NSMutableArray<NSString *> *values = [NSMutableArray array];
    for (NSUInteger i = 0; i < self.count; ++i)
        [values addObject:[self.type _value_describeBytes:(uint8_t *)bytes + [self offsetForElementAtIndex:i] additionalInfo:info]];
    return [NSString stringWithFormat:@"{ %@ }", [values componentsJoinedByString:@", "]];
}

- (ffi_type *)_ffi_type {
    return &ffi_type_pointer;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDAggregateType(RDPrivate)
@end

@implementation RDAggregateType(RDPrivate)

- (void)_value_retainBytes:(void *)bytes {
    if (bytes != NULL && self.kind == RDAggregateTypeKindStruct)
        for (NSUInteger i = 0; i < self.count; ++i)
            if (RDField *field = [self fieldAtIndex:i]; field != NULL && field->offset != RDOffsetUnknown)
                [field->type _value_retainBytes:(uint8_t *)bytes + field->offset];
}

- (void)_value_releaseBytes:(void *)bytes {
    if (bytes != NULL && self.kind == RDAggregateTypeKindStruct)
        for (NSUInteger i = 0; i < self.count; ++i)
            if (RDField *field = [self fieldAtIndex:i]; field != NULL && field->offset != RDOffsetUnknown)
                [field->type _value_releaseBytes:(uint8_t *)bytes + field->offset];
}

- (NSString *)_value_describeBytes:(void *)bytes additionalInfo:(NSMutableArray<NSString *> *)info {
    NSMutableArray<NSString *> *values = [NSMutableArray array];
    for (NSUInteger i = 0; i < self.count; ++i)
        if (RDField *field = [self fieldAtIndex:i]; field != NULL && field->offset != RDOffsetUnknown)
            [values addObject:[NSString stringWithFormat:@".%@ = %@",
                               field->name ?: [NSString stringWithFormat:@"field%zu", i],
                               [field->type _value_describeBytes:(uint8_t *)bytes + field->offset additionalInfo:info]]];

    return [NSString stringWithFormat:@"(%@%@) { %@ }",
                                      self.kind == RDAggregateTypeKindUnion ? @"union" : @"struct",
                                      self.name ? [NSString stringWithFormat:@" %@", self.name] : @"",
                                      [values componentsJoinedByString:@", "]];
}

- (ffi_type *)_ffi_type {
    switch (self.kind) {
        case RDAggregateTypeKindUnion:
            return NULL;
        case RDAggregateTypeKindStruct:
            ffi_type *types = (ffi_type *)calloc(1, sizeof(ffi_type) + sizeof(ffi_type *) * (self.count + 1));
            types->type = FFI_TYPE_STRUCT;
            types->size = 0;
            types->alignment = 0;
            types->elements = (ffi_type **)(types + 1);
            
            for (NSUInteger i = 0; i < self.count; ++i)
                if (RDField *field = [self fieldAtIndex:i]; field != NULL)
                    types->elements[i] = field->type._ffi_type;
            
            types->elements[self.count] = NULL;
            
            return types;
    }
}

@end


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
