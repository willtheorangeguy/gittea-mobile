#!/usr/bin/env python3
"""Generate the dependency-free Xcode project with deterministic object identifiers."""
import hashlib
from pathlib import Path

root = Path(__file__).resolve().parent.parent
objects = {}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(name, value):
    key = uid(name)
    objects[key] = value
    return key
def array(items): return '(' + ', '.join(items) + ',)' if items else '()'
def quote(value): return '"' + str(value).replace('"', '\\"') + '"'
def settings(values): return '{' + ' '.join(f'{k} = {quote(v)};' for k,v in values.items()) + '}'

products, groups, targets = [], [], []
for name, folder, producttype in [('Gitea', 'Gitea', 'application'), ('GiteaTests', 'GiteaTests', 'bundle.unit-test'), ('GiteaUITests', 'GiteaUITests', 'bundle.ui-testing')]:
    files, sources, resources = [], [], []
    paths = sorted((root / folder).rglob('*.swift'))
    if name == 'Gitea': paths += [root/'Gitea/Assets.xcassets', root/'Gitea/PrivacyInfo.xcprivacy', root/'Gitea/Info.plist']
    for path in paths:
        rel = str(path.relative_to(root))
        typ = 'sourcecode.swift' if path.suffix == '.swift' else 'folder.assetcatalog' if path.suffix == '.xcassets' else 'text.xml'
        ref = add(rel, f'{{isa = PBXFileReference; lastKnownFileType = {typ}; path = {quote(rel)}; sourceTree = SOURCE_ROOT;}}')
        files.append(ref)
        if path.name != 'Info.plist':
            build = add('build:'+rel, f'{{isa = PBXBuildFile; fileRef = {ref};}}')
            (sources if path.suffix == '.swift' else resources).append(build)
    group = add('group:'+name, f'{{isa = PBXGroup; children = {array(files)}; name = {name}; sourceTree = "<group>";}}')
    groups.append(group)
    ext = 'app' if name == 'Gitea' else 'xctest'
    prod = add('product:'+name, f'{{isa = PBXFileReference; explicitFileType = {"wrapper.application" if ext == "app" else "wrapper.cfbundle"}; includeInIndex = 0; path = {name}.{ext}; sourceTree = BUILT_PRODUCTS_DIR;}}')
    products.append(prod)
    phases = []
    for phase, isa, contents in [('sources', 'PBXSourcesBuildPhase', sources), ('frameworks', 'PBXFrameworksBuildPhase', []), ('resources', 'PBXResourcesBuildPhase', resources)]:
        phases.append(add(phase+':'+name, f'{{isa = {isa}; buildActionMask = 2147483647; files = {array(contents)}; runOnlyForDeploymentPostprocessing = 0;}}'))
    configs = []
    for mode in ['Debug', 'Release']:
        config = {'PRODUCT_NAME': '$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER': 'app.gitea.mobile' + ('' if name == 'Gitea' else '.'+name), 'SWIFT_VERSION': '5.0', 'TARGETED_DEVICE_FAMILY': '1,2', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0', 'CODE_SIGN_STYLE': 'Automatic', 'GENERATE_INFOPLIST_FILE': 'YES', 'SWIFT_EMIT_LOC_STRINGS': 'YES', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator'}
        if name == 'Gitea': config.update({'INFOPLIST_FILE': 'Gitea/Info.plist', 'GENERATE_INFOPLIST_FILE': 'NO', 'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon', 'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME': 'AccentColor', 'ENABLE_PREVIEWS': 'YES', 'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks'})
        elif name == 'GiteaTests': config.update({'TEST_HOST': '$(BUILT_PRODUCTS_DIR)/Gitea.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Gitea', 'BUNDLE_LOADER': '$(TEST_HOST)'})
        else: config['TEST_TARGET_NAME'] = 'Gitea'
        configs.append(add(mode+':'+name, f'{{isa = XCBuildConfiguration; buildSettings = {settings(config)}; name = {mode};}}'))
    configlist = add('configs:'+name, f'{{isa = XCConfigurationList; buildConfigurations = {array(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}}')
    dependencies = []
    if name != 'Gitea':
        proxy = add('proxy:'+name, f'{{isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("target:Gitea")}; remoteInfo = Gitea;}}')
        dependencies.append(add('dependency:'+name, f'{{isa = PBXTargetDependency; target = {uid("target:Gitea")}; targetProxy = {proxy};}}'))
    targets.append(add('target:'+name, f'{{isa = PBXNativeTarget; buildConfigurationList = {configlist}; buildPhases = {array(phases)}; buildRules = (); dependencies = {array(dependencies)}; name = {name}; productName = {name}; productReference = {prod}; productType = "com.apple.product-type.{producttype}";}}'))

productgroup = add('products', f'{{isa = PBXGroup; children = {array(products)}; name = Products; sourceTree = "<group>";}}')
main = add('main', f'{{isa = PBXGroup; children = {array(groups+[productgroup])}; sourceTree = "<group>";}}')
configs = []
for mode in ['Debug', 'Release']:
    config = {'SDKROOT': 'iphoneos', 'CLANG_ENABLE_MODULES': 'YES', 'CLANG_ENABLE_OBJC_ARC': 'YES', 'ENABLE_USER_SCRIPT_SANDBOXING': 'YES', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0', 'DEBUG_INFORMATION_FORMAT': 'dwarf' if mode == 'Debug' else 'dwarf-with-dsym', 'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if mode == 'Debug' else '-O', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'DEBUG' if mode == 'Debug' else '', 'ENABLE_TESTABILITY': 'YES' if mode == 'Debug' else 'NO', 'ONLY_ACTIVE_ARCH': 'YES' if mode == 'Debug' else 'NO'}
    configs.append(add('project:'+mode, f'{{isa = XCBuildConfiguration; buildSettings = {settings(config)}; name = {mode};}}'))
configlist = add('projectconfigs', f'{{isa = XCConfigurationList; buildConfigurations = {array(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}}')
project = add('project', f'{{isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = YES; LastSwiftUpdateCheck = 1600; LastUpgradeCheck = 1600;}}; buildConfigurationList = {configlist}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main}; productRefGroup = {productgroup}; projectDirPath = ""; projectRoot = ""; targets = {array(targets)};}}')
projectdir = root/'Gitea.xcodeproj'
projectdir.mkdir(exist_ok=True)
(projectdir/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(f'{k} = {v};' for k,v in objects.items())+f'\n}}; rootObject = {project};}}\n')
schemedir = projectdir/'xcshareddata/xcschemes'
schemedir.mkdir(parents=True, exist_ok=True)
def ref(name): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target:"+name)}" BuildableName="{name}.{ "app" if name == "Gitea" else "xctest"}" BlueprintName="{name}" ReferencedContainer="container:Gitea.xcodeproj"/>'
(schemedir/'Gitea.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref('Gitea')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref('GiteaTests')}</TestableReference><TestableReference skipped="NO">{ref('GiteaUITests')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('Gitea')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('Gitea')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated Gitea.xcodeproj')
