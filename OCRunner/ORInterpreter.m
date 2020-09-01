//
//  ORInterpreter.m
//  OCRunner
//
//  Created by Jiang on 2020/5/23.
//  Copyright © 2020 SilverFruity. All rights reserved.
//

#import "ORInterpreter.h"
#import "RunnerClasses+Execute.h"
#import "MFScopeChain.h"
#import "ORSearchedFunction.h"
#import "MFValue.h"
#import "ORStructDeclare.h"
#import "ORSystemFunctionTable.h"

@implementation ORInterpreter
+ (void)excuteBinaryPatchFile:(NSString *)path{
    
    
    //加载补丁文件
    ORPatchFile *file = [ORPatchFile loadBinaryPatch:path];
    
    //如果版本判断未通过，则为nil
    if (file == nil) {
        return;
    }
    [self excuteNodes:file.nodes];
}

+ (void)excuteNodes:(NSArray <ORNode *>*)nodes{
    MFScopeChain *scope = [MFScopeChain topScope];
    
    //添加函数、变量等
    mf_add_built_in(scope);
    
    //链接函数指针，过滤一次
    nodes = [self linkFunctions:nodes scope:scope];
    
    //注册Protcol 注册Class 全局函数声明等
    for (ORNode *node in nodes) {
        [node execute:scope];
    }
}
+ (NSArray *)linkFunctions:(NSArray *)nodes scope:(MFScopeChain *)scope{
    NSMutableArray <ORTypeVarPair *>*funcVars = [NSMutableArray array];
    NSMutableArray *normalStatements = [NSMutableArray array];
    NSMutableArray *names = [NSMutableArray array];
    for (id <OCExecute> expression in nodes) {
        if ([expression isKindOfClass:[ORDeclareExpression class]]) {
            ORTypeVarPair *pair = [(ORDeclareExpression *)expression pair];
            if ([pair.var isKindOfClass:[ORFuncVariable class]]) {
                [funcVars addObject:pair];
                [names addObject:pair.var.varname];
                continue;
            }
        }
        //过滤 link functions
        [normalStatements addObject:expression];
    }
    //获取函数指针
    NSDictionary *table = [ORSearchedFunction functionTableForNames:names];
    for (ORTypeVarPair *pair in funcVars) {
        ORSearchedFunction *function = table[pair.var.varname];
        function.funPair = pair;
        if ([scope getValueWithIdentifier:function.name] == nil) {
            [scope setValue:[MFValue valueWithObject:function] withIndentifier:function.name];
        }
    }
    #if DEBUG
    NSMutableArray *functionNames = [NSMutableArray array];
    for (ORTypeVarPair *pair in funcVars){
        NSString *functionName = pair.var.varname;
        ORSearchedFunction *function = table[functionName];
        if (function.pointer == NULL
            && [ORSystemFunctionTable pointerForFunctionName:functionName] == NULL) {
            MFValue *value = [[MFScopeChain topScope] getValueWithIdentifier:functionName];
            if (value == nil || [value.objectValue isKindOfClass:[ORSearchedFunction class]]) {
                [functionNames addObject:functionName];
            }
        }
    }
    if (functionNames.count > 0) {
        NSMutableString *build_ins = [@"" mutableCopy];
        [build_ins appendString:@"\n|----------------------------------------------|"];
        [build_ins appendString:@"\n|❕you need add ⬇️ code in the application file|"];
        [build_ins appendString:@"\n|----------------------------------------------|\n"];
        for (NSString *name in functionNames) {
            NSString *build_in_declare = [NSString stringWithFormat:@"[ORSystemFunctionTable reg:@\"%@\" pointer:&%@];\n",name,name];
            [build_ins appendString:build_in_declare];
        }
        [build_ins appendString:@"-----------------------------------------------"];
        NSLog(@"%@", build_ins);
    }
    #endif
    return normalStatements;
}
@end
