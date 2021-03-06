"
I provide the API of the whole Compiler Package for the case that the input is sourcecode.
(if there is alreay and AST, call #generate (to compile) or #evaluate directly on the node)

a pre-configures compiler instance can be requested with: 
 - Smalltalk compiler
 - a Class compiler 

The compiler instance (atually: the compilation context) needs to be setup. See #class: #source: #noPattern: #requestor: for the most important accessors (more are in the accessing protocol). 

See the class comment of CompilationContext for more information.

The final step is one of three actions:

-> parsing: parse source and return an AST.
-> compile: parse and compile, return a CompiledMethod 
-> evaluate: parse, compile, evaluate and return result

Example:

Smalltalk compiler
	source: 'test 1+2';
	class: Object;
	compile.

This returns a CompiledMethod.
"
Class {
	#name : #OpalCompiler,
	#superclass : #AbstractCompiler,
	#instVars : [
		'ast',
		'source',
		'context',
		'receiver',
		'compilationContext',
		'compilationContextClass'
	],
	#classInstVars : [
		'overlayEnvironment'
	],
	#category : #'OpalCompiler-Core-FrontEnd'
}

{ #category : #options }
OpalCompiler class >> compilerSpecificSettingsOn: aBuilder [
	(aBuilder pickOne: #bytecodeBackend)
		order: 0;
		target: CompilationContext;
		description: 'Sets the bytecode encoding of the compiled code generated by the Opal compiler';
		label: 'Bytecode Backend';
		domainValues:
				{#V3PlusClosures -> EncoderForV3PlusClosures.
				#SistaV1 -> EncoderForSistaV1 }.
	CompilationContext compilerSpecificSettingsOn: aBuilder.
	
]

{ #category : #overlay }
OpalCompiler class >> createAndEnableOverlay [
	^self overlayIsActive
]

{ #category : #overlay }
OpalCompiler class >> createAndEnableOverlay: aBoolean [
	
	aBoolean = self overlayIsActive ifTrue: [ ^self ].
	aBoolean 
		ifTrue: [ self startUsingOverlayForDevelopment   ]
		ifFalse: [ self stopUsingOverlayForDevelopment   ]
]

{ #category : #public }
OpalCompiler class >> debuggerMethodMapForMethod: aMethod [
	^ DebuggerMethodMapOpal forMethod: aMethod
]

{ #category : #'old - deprecated' }
OpalCompiler class >> evaluate: textOrString [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith: '`@receiver evaluate: `@statements1 ' -> '`@receiver new source: `@statements1; evaluate'.
	^ self new
		source: textOrString;
		evaluate
]

{ #category : #'old - deprecated' }
OpalCompiler class >> evaluate: textOrString for: anObject logged: logFlag [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith:
			'`@receiver evaluate: `@statements1 for: `@statements2 logged: `@statements3 '
				-> '`@receiver new source: `@statements1; logged: `@statements3; receiver: `@statements2; evaluate.'.
	^ self new
		source: textOrString;
		logged: logFlag;
		receiver: anObject;
		evaluate
]

{ #category : #'old - deprecated' }
OpalCompiler class >> evaluate: textOrString for: anObject notifying: aController logged: logFlag [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith:
			'`@receiver evaluate: `@statements1 for: `@statements2 notifying: `@statements3 logged: `@statements4'
				-> '`@receiver new source: `@statements1; logged: `@statements4; receiver: `@statements2; requestor: `@statements3; evaluate'.
	^ self new
		source: textOrString;
		logged: logFlag;
		receiver: anObject;
		requestor: aController;
		evaluate
]

{ #category : #'old - deprecated' }
OpalCompiler class >> evaluate: textOrString logged: logFlag [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith: '`@receiver evaluate: `@statements1 logged: `@statements2 ' -> '`@receiver new source: `@statements1; logged: `@statements2; evaluate.'.
	^ self new
		source: textOrString;
		logged: logFlag;
		evaluate
]

{ #category : #'old - deprecated' }
OpalCompiler class >> evaluate: textOrString notifying: aController logged: logFlag [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith:
			'`@receiver evaluate: `@statements1 notifying: `@statements2 logged: `@statements3'
				-> '`@receiver new source: `@statements1; logged: `@statements3; requestor: `@statements2; evaluate'.
	^ self new
		source: textOrString;
		logged: logFlag;
		requestor: aController;
		evaluate
]

{ #category : #'old - deprecated' }
OpalCompiler class >> format: textOrStream in: aClass notifying: aRequestor [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith:
			'`@receiver format: `@statements1 in: `@statements2 notifying: `@statements3'
				-> '`@receiver new source: `@statements1; class: `@statements2; requestor: `@statements3; format'.
	^ self new
		source: textOrStream;
		class: aClass;
		requestor: aRequestor;
		format
]

{ #category : #public }
OpalCompiler class >> isActive [
	^Smalltalk compilerClass == self
]

{ #category : #overlay }
OpalCompiler class >> overlayEnvironment [
	^overlayEnvironment
]

{ #category : #overlay }
OpalCompiler class >> overlayIsActive [
	^overlayEnvironment notNil
]

{ #category : #public }
OpalCompiler class >> recompileAll [
	"Recompile all classes and traits in the system."

	Smalltalk image recompile



]

{ #category : #overlay }
OpalCompiler class >> startUsingOverlayForDevelopment [
	"this method sets up an overlay so we can change the compiler package without breaking the compiler"

	<script>
	overlayEnvironment := Dictionary new.

	"now we put a copy of all the classes of the compiler package into the environment"
	self package definedClasses
		do: [ :class | overlayEnvironment at: class name put: class copy ].

	"now we recompile the classes in the environment with itself as an overlay"
	overlayEnvironment valuesDo: [ :class | 
			class methodsDo: [ :method | 
					| newMethod |
					newMethod := class compiler
						bindings: overlayEnvironment;
						compile: method sourceCode.
					class addSelectorSilently: method selector withMethod: newMethod ] ].
	
	"make sure superclass pointers are correct"
    overlayEnvironment valuesDo: [ :class | 
        (overlayEnvironment includesKey: class superclass name) ifTrue: [  
            class superclass: (overlayEnvironment at: class superclass name)]].
	
	"make the copy the default compiler for the image"
	SmalltalkImage compilerClass: (overlayEnvironment at: #OpalCompiler).
	ASTCache reset.
]

{ #category : #overlay }
OpalCompiler class >> stopUsingOverlayForDevelopment [
	"set compiler back to normal and throw away overlay environment"

	<script>
	SmalltalkImage compilerClass: nil.
	overlayEnvironment := nil.
	ASTCache reset
]

{ #category : #plugins }
OpalCompiler >> addPlugin: aClass [ 
	compilationContext addASTTransformationPlugin: aClass
]

{ #category : #accessing }
OpalCompiler >> bindings: aDictionary [
	"allows to define additional binding, note: Globals are not shadowed"
	self compilationContext bindings: aDictionary
]

{ #category : #private }
OpalCompiler >> callPlugins [
	| plugins  |
	plugins := compilationContext astTransformPlugins ifEmpty: [ ^self ].
	plugins sort: [:a :b | a priority > b priority]. "priority 0 is sorted last"
	ast := ast copy.
	plugins do: [ :each | ast := each transform: ast]. 
]

{ #category : #accessing }
OpalCompiler >> class: aClass [
	self compilationContext class: aClass.
]

{ #category : #accessing }
OpalCompiler >> compilationContext [
	^ compilationContext ifNil: [ compilationContext := self compilationContextClass default ]
]

{ #category : #accessing }
OpalCompiler >> compilationContext: anObject [
	compilationContext := anObject
]

{ #category : #plugins }
OpalCompiler >> compilationContextClass [
	^compilationContextClass ifNil: [ CompilationContext  ]
]

{ #category : #plugins }
OpalCompiler >> compilationContextClass: aClass [
	compilationContextClass := aClass.
]

{ #category : #'public access' }
OpalCompiler >> compile [
	| cm |
	[ 	[	self parse.
			self doSemanticAnalysis. 
			self callPlugins.  
		] 	on: ReparseAfterSourceEditing 
			do: 
			[  	:notification | 
				self source: notification newSource. 
				notification retry. 
			]. 
		cm := compilationContext optionEmbeddSources
			ifTrue: [ ast generateWithSource ]
			ifFalse: [ast generate: self compilationContext compiledMethodTrailer   ]
		
	]	on: SyntaxErrorNotification 
		do: [ :exception | 
			self compilationContext requestor
                ifNotNil: [
						self compilationContext requestor 
							notify: exception errorMessage , ' ->'
							at: exception location
							in: exception errorCode.
                    ^ self compilationContext failBlock value ]
                ifNil: [ exception pass ]].
	^cm
]

{ #category : #'public access' }
OpalCompiler >> compile: textOrString [ 
	
	^self
		source: textOrString;
		compile.
]

{ #category : #'old - deprecated' }
OpalCompiler >> compile: textOrStream in: aClass classified: aCategory notifying: aRequestor ifFail: aFailBlock [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith:
			'`@receiver compile: `@statements1 in: `@statements2 classified: `@statements3 notifying: `@statements4 ifFail: `@statements5'
				-> '`@receiver 	source:  `@statements1; class: `@statements2; requestor: `@statements4; failBlock: `@statements5; parse'.
	^ self
		source: textOrStream;
		class: aClass;
		requestor: aRequestor;
		failBlock: aFailBlock;
		parse
]

{ #category : #'old - deprecated' }
OpalCompiler >> compile: textOrStream in: aClass notifying: aRequestor ifFail: aFailBlock [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith:
			'`@receiver compile: `@statements1 in: `@statements2 notifying: `@statements3 ifFail: `@statements4'
				-> '`@receiver source: `@statements1; class: `@statements2; requestor: `@statements3; failBlock: `@statements4; parse'.
	^ self
		source: textOrStream;
		class: aClass;
		requestor: aRequestor;
		failBlock: aFailBlock;
		parse
]

{ #category : #'old - deprecated' }
OpalCompiler >> compileNoPattern: textOrStream in: aClass context: aContext notifying: aRequestor ifFail: aFailBlock [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith:
			'`@receiver compileNoPattern: `@statements1 in: `@statements2 context: `@statements3 notifying: `@statements4 ifFail: `@statements5'
				-> '`@receiver source: `@statements1; class: `@statements2; context: `@statements3; requestor: `@statements4; noPattern: true; failBlock: `@statements5; parse'.

	^self 
		source: textOrStream;
		class: aClass;
		context: aContext;
		requestor: aRequestor;
		noPattern: true;
		failBlock: aFailBlock;
		parse
]

{ #category : #accessing }
OpalCompiler >> compiledMethodTrailer: bytes [
	self compilationContext compiledMethodTrailer: bytes
]

{ #category : #accessing }
OpalCompiler >> context: aContext [
	context  := aContext
]

{ #category : #'public access' }
OpalCompiler >> decompileMethod: aCompiledMethod [
	^ Smalltalk globals 
		at: #FBDDecompiler  
		ifPresent: [ :decompilerClass | [ decompilerClass new decompile: aCompiledMethod ]
			on: Error 
			do: [ RBMethodNode errorMethodNode: aCompiledMethod selector errorMessage: 'Decompilation failed'.  ] ]
		ifAbsent: [ RBMethodNode errorMethodNode: aCompiledMethod selector errorMessage: 'No decompiler available'. ]


]

{ #category : #private }
OpalCompiler >> doSemanticAnalysis [
	^[ast doSemanticAnalysis] 
		on: OCSemanticError 
		do: [ :ex | ex defaultAction. ^ self compilationContext failBlock value ]
]

{ #category : #plugins }
OpalCompiler >> encoderClass: aClass [ 
	self compilationContext encoderClass: aClass 
]

{ #category : #accessing }
OpalCompiler >> environment: anSmallTalkImage [
	self compilationContext environment: anSmallTalkImage 
]

{ #category : #'public access' }
OpalCompiler >> evaluate [
	"Compiles the sourceStream into a parse tree, then generates code into
	 a method. If aContext is not nil, the text can refer to temporaries in that
	 context (the Debugger uses this). If aRequestor is not nil, then it will receive
	 a notify:at: message before the attempt to evaluate is aborted. Finally, the 
	 compiled method is invoked from here via withArgs:executeMethod:, hence
	 the system no longer creates Doit method litter on errors."

	| value |
	self noPattern: true.
	self getSourceFromRequestorSelection.
	self class: (context ifNil: [ receiver class ] ifNotNil: [ context method methodClass ]).
	value := receiver withArgs: (context ifNil: [ #() ] ifNotNil: [ {context} ]) executeMethod: self compile.
	self logDoIt.
	^ value
]

{ #category : #'public access' }
OpalCompiler >> evaluate: textOrString [ 
	
	^self
		source: textOrString;
		evaluate
]

{ #category : #'old - deprecated' }
OpalCompiler >> evaluate: textOrString for: anObject logged: logFlag [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith:
			'`@receiver evaluate: `@statements1 for: `@statements2 logged: `@statements3'
				->
					'`@receiver source: `@statements1; logged: `@statements3; receiver: `@statements2; evaluate'.
	^ self
		source: textOrString;
		logged: logFlag;
		receiver: anObject;
		evaluate
]

{ #category : #'old - deprecated' }
OpalCompiler >> evaluate: textOrString for: anObject notifying: aController logged: logFlag [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith:
			'`@receiver evaluate: `@statements1 for: `@statements2 notifying: `@statements3 logged: `@statements4'
				-> '`@receiver source: `@statements1; logged: `@statements2; receiver: `@statements3; requestor: `@statements4; evaluate'.
	^ self
		source: textOrString;
		logged: logFlag;
		receiver: anObject;
		requestor: aController;
		evaluate
]

{ #category : #'old - deprecated' }
OpalCompiler >> evaluate: aString in: aContext to: aReceiver [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith: '`@receiver evaluate: `@statements1 in: `@statements2 to: `@statements3' 
						-> '`@receiver source: `@statements1; context: `@statements2; receiver: `@statements3;  parse.'.
	
	^self
		source: aString;
		context: aContext;
		receiver: aReceiver;
		failBlock: [^ #failedDoit];
		evaluate
]

{ #category : #'old - deprecated' }
OpalCompiler >> evaluate: textOrStream in: aContext to: aReceiver notifying: aRequestor ifFail: aFailBlock [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith:
			'`@receiver evaluate: `@statements1 in: `@statements2 to: `@statements3 notifying: `@statements4 ifFail: `@statements5'
				->
					'`@receiver source: `@statements1; context: `@statements2; receiver: `@statements3; requestor: `@statements4; failBlock: `@statements5; evaluate'.
	^ self
		source: textOrStream;
		context: aContext;
		receiver: aReceiver;
		requestor: aRequestor;
		failBlock: aFailBlock;
		evaluate
]

{ #category : #'old - deprecated' }
OpalCompiler >> evaluate: textOrStream in: aContext to: aReceiver notifying: aRequestor ifFail: aFailBlock logged: logFlag [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith:
			'`@receiver evaluate: `@statements1 in: `@statements2 to: `@statements3 notifying: `@statements4 ifFail: `@statements5 logged:  `@statements6'
				-> '`@receiver source: `@statements1; context: `@statements2; receiver: `@statements3; requestor: `@statements4; failBlock: `@statements5; logged: `@statements6; evaluate'.
	^ self
		source: textOrStream;
		context: aContext;
		receiver: aReceiver;
		requestor: aRequestor;
		failBlock: aFailBlock;
		logged: logFlag;
		evaluate
]

{ #category : #'old - deprecated' }
OpalCompiler >> evaluate: textOrString logged: logFlag [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith: '`@receiver evaluate: `@statements1 logged: `@statements2' 
			-> '`@receiver source: `@statements1; logged: `@statements2; evaluate'.
	^ self
		source: textOrString;
		logged: logFlag;
		evaluate
]

{ #category : #'old - deprecated' }
OpalCompiler >> evaluate: textOrString notifying: aController logged: logFlag [ 
	self
		deprecated: 'Please use new compiler API instead'
		transformWith: '`@receiver evaluate: `@statements1 notifying: `@statements2 logged: `@statements3' 
						-> '`@receiver source: `@statements1; logged: `@statements2; requestor:  `@statements3; evaluate'.

	^ self
		source: textOrString;
		logged: logFlag;
		requestor: aController;
		evaluate
	
]

{ #category : #accessing }
OpalCompiler >> failBlock: aBlock [
	self compilationContext failBlock: aBlock.
]

{ #category : #'public access' }
OpalCompiler >> format [
	^self parse formattedCode.
]

{ #category : #'public access' }
OpalCompiler >> format: textOrString [ 
	
	^self
		source: textOrString;
		format
]

{ #category : #'old - deprecated' }
OpalCompiler >> format: textOrStream in: aClass notifying: aRequestor [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith: '`@receiver format: `@statements1 in: `@statements2 notifying: `@statements3' 
					-> '`@receiver source:  `@statements1; class: `@statements2; requestor: `@statements3; format'.
	^ self
		source: textOrStream;
		class: aClass;
		requestor: aRequestor;
		format
]

{ #category : #private }
OpalCompiler >> getSourceFromRequestorSelection [
    | selectionString |
    "if the requestor can provide a selection, we use that as the source"
     (self compilationContext requestor respondsTo: #selection) ifFalse: [ ^self ].
    
    selectionString := self compilationContext requestor selection asString.
    selectionString isEmptyOrNil ifTrue: [ ^self ].
    self source: selectionString.
]

{ #category : #private }
OpalCompiler >> isInteractiveFor: aRequestor [
	"the requester can override if the compiler is interactive or not"
	aRequestor ifNil: [^ false ].
	^(aRequestor respondsTo: #interactive)
		ifTrue: [ aRequestor interactive ]
		ifFalse: [ true ]
]

{ #category : #private }
OpalCompiler >> logDoIt [
	self compilationContext logged ifFalse: [ ^self ].
	Smalltalk globals 
			at: #SystemAnnouncer 
			ifPresent: [ :sysAnn | 
				sysAnn uniqueInstance evaluated: source contents context: context ]
]

{ #category : #accessing }
OpalCompiler >> logged: aBoolean [
	self compilationContext logged:  aBoolean.
]

{ #category : #accessing }
OpalCompiler >> noPattern: aBoolean [
	self compilationContext noPattern: aBoolean.
	"when we compile an expression, embedd sources, as the resulting method will never be installed"
	compilationContext parseOptions: #(+ #optionEmbeddSources).
	
]

{ #category : #'public access' }
OpalCompiler >> options: anOptionsArray [
	self compilationContext parseOptions: anOptionsArray
]

{ #category : #'public access' }
OpalCompiler >> parse [
	^self compilationContext noPattern 
		ifTrue: [ self parseExpression ]
		ifFalse: [ self parseMethod ].
]

{ #category : #'public access' }
OpalCompiler >> parse: textOrString [ 
	
	^self
		source: textOrString;
		parse
]

{ #category : #'old - deprecated' }
OpalCompiler >> parse: aString class: aClass [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith: '`@receiver parse: `@statements1 class: `@statements2' 
						-> '`@receiver source: `@statements1; class: `@statements2; parse.'.
	^self 
		source: aString;
		class: aClass;
		parse
]

{ #category : #'old - deprecated' }
OpalCompiler >> parse: aString class: aClass noPattern: aBoolean context: aContext notifying: req ifFail: aBlock [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith:
			'`@receiver parse: `@statements1 class: `@statements2 noPattern: `@statements3 context: `@statements4 notifying: `@statements5 ifFail: `@statements6'
				->'`@receiver source: `@statements1; class: `@statements2; noPattern: `@statements3; context: `@statements4; requestor: `@statements5; failBlock: `@statements6; parse.'.
	^ self
		source: aString;
		class: aClass;
		noPattern: aBoolean;
		context: aContext;
		requestor: req;
		failBlock: aBlock;
		parse
]

{ #category : #'old - deprecated' }
OpalCompiler >> parse: textOrStream in: aClass notifying: req [
	self
		deprecated: 'Please use new compiler API instead'
		transformWith:
			'`@receiver parse: `@statements1 in: `@statements2 notifying: `@statements3' -> '`@receiver source: `@statements1; class: `@statements2; requestor: `@statements3; parse.'.
	^ self
		source: textOrStream;
		class: aClass;
		requestor: req;
		parse
]

{ #category : #private }
OpalCompiler >> parseExpression [
	| expression |

	expression := self compilationContext optionParseErrors 
		ifTrue: [self parserClass parseFaultyExpression: source contents]
		ifFalse: [self parserClass parseExpression: source contents].	
	ast := context 
		ifNil: [expression asDoit] 
		ifNotNil: [expression asDoitForContext: context].
	ast compilationContext: self compilationContext.
	^ast.
]

{ #category : #'public access' }
OpalCompiler >> parseLiterals: aString [
	^self parserClass parseLiterals: aString
]

{ #category : #private }
OpalCompiler >> parseMethod [
	
	ast := self compilationContext optionParseErrors 
		ifTrue: [self parserClass parseFaultyMethod: source contents]
		ifFalse: [self parserClass parseMethod: source contents].
	ast compilationContext: self compilationContext.
	^ast.

]

{ #category : #'public access' }
OpalCompiler >> parseSelector: aString [ 
	"Answer the message selector for the argument, aString, which should parse successfully up to the temporary declaration or the end of the method header."
	
	^[self parserClass parseMethodPattern: aString] on: Error do: [nil].
]

{ #category : #plugins }
OpalCompiler >> parserClass [
	^self compilationContext parserClass
]

{ #category : #accessing }
OpalCompiler >> receiver: anObject [
	receiver := anObject.
]

{ #category : #accessing }
OpalCompiler >> requestor: aRequestor [
	self compilationContext requestor: aRequestor.
	self compilationContext interactive: (self isInteractiveFor: aRequestor).
]

{ #category : #plugins }
OpalCompiler >> requestorScopeClass: aClass [ 
	"clients can set their own subclass of OCRequestorScope if needed"
	self compilationContext requestorScopeClass: aClass
]

{ #category : #accessing }
OpalCompiler >> source: aString [
	source := aString readStream.
]

{ #category : #'old - deprecated' }
OpalCompiler >> translate [
	self
		deprecated: 'Please use #parse instead'
		transformWith: '`@receiver translate' -> '`@receiver parse'.
	^self parse.
]
