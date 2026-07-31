flowchart LR

    %% الكيانات (Entities)
    USERS["USERS<br/>المستخدمون"]
    ROLES["ROLES<br/>الأدوار"]
    PERMISSIONS["PERMISSIONS<br/>الصلاحيات"]
    DEPARTMENTS["DEPARTMENTS<br/>الأقسام"]
    CATEGORIES["CATEGORIES<br/>تصنيفات البلاغات"]

    %% العلاقات (Relationships)
    HAS_ROLE{"HAS_ROLE<br/>يمتلك دور"}
    ROLE_PERMISSION{"ROLE_PERMISSION<br/>صلاحيات الدور"}
    BELONGS_TO{"BELONGS_TO<br/>ينتمي إلى"}
    HAS_CATEGORY{"HAS_CATEGORY<br/>يمتلك تصنيف"}

    %% الربط والتعددية (Connections & Cardinality)
    USERS ---|N| HAS_ROLE
    HAS_ROLE ---|1| ROLES

    ROLES ---|M| ROLE_PERMISSION
    ROLE_PERMISSION ---|N| PERMISSIONS

    USERS ---|"0..1"| BELONGS_TO
    BELONGS_TO ---|1| DEPARTMENTS

    DEPARTMENTS ---|1| HAS_CATEGORY
    HAS_CATEGORY ---|N| CATEGORIES

    %% التنسيق والألوان (Styling)
    classDef entity fill:#DCEBFA,stroke:#34495E,stroke-width:1.5px,color:#000;
    classDef relationship fill:#BFCAD3,stroke:#34495E,stroke-width:1.5px,color:#000;

    class USERS,ROLES,PERMISSIONS,DEPARTMENTS,CATEGORIES entity;
    class HAS_ROLE,ROLE_PERMISSION,BELONGS_TO,HAS_CATEGORY relationship;

------------------------------------------------------------------------------
flowchart LR

    %% الكيانات (Entities)
    USERS["USERS<br/>المستخدمون"]
    REPORTS["REPORTS<br/>البلاغات"]
    CATEGORIES["CATEGORIES<br/>تصنيفات البلاغات"]
    DEPARTMENTS["DEPARTMENTS<br/>الأقسام"]
    AREAS["AREAS<br/>المناطق"]

    %% العلاقات (Relationships)
    CREATES{"CREATES<br/>ينشئ"}
    CLASSIFIED_AS{"CLASSIFIED_AS<br/>مصنف كـ"}
    ASSIGNED_TO{"ASSIGNED_TO<br/>محال إلى"}
    LOCATED_IN{"LOCATED_IN<br/>يقع في"}
    SIMILAR_TO{"SIMILAR_TO<br/>مشابه لـ"}

    %% الربط والتعددية (Connections & Cardinality)
    USERS ---|1| CREATES
    CREATES ---|N| REPORTS

    CATEGORIES ---|1| CLASSIFIED_AS
    CLASSIFIED_AS ---|N| REPORTS

    DEPARTMENTS ---|1| ASSIGNED_TO
    ASSIGNED_TO ---|N| REPORTS

    AREAS ---|1| LOCATED_IN
    LOCATED_IN ---|N| REPORTS

    REPORTS ---|"0..1"| SIMILAR_TO
    SIMILAR_TO ---|N| REPORTS

    %% التنسيق والألوان (Styling)
    classDef entity fill:#DCEBFA,stroke:#34495E,stroke-width:1.5px,color:#000;
    classDef relationship fill:#BFCAD3,stroke:#34495E,stroke-width:1.5px,color:#000;

    class USERS,REPORTS,CATEGORIES,DEPARTMENTS,AREAS entity;
    class CREATES,CLASSIFIED_AS,ASSIGNED_TO,LOCATED_IN,SIMILAR_TO relationship;
----------------------------------------------------------------------------------
flowchart LR

    %% الكيانات (Entities)
    USERS["USERS<br/>المستخدمون"]
    REPORTS["REPORTS<br/>البلاغات"]
    REPORT_IMAGES["REPORT_IMAGES<br/>صور البلاغات"]
    REPORT_LOGS["REPORT_LOGS<br/>سجل حركة البلاغ"]

    %% العلاقات (Relationships)
    HAS_IMAGE{"HAS_IMAGE<br/>يحتوي صورة"}
    UPLOADS{"UPLOADS<br/>يرفع"}
    HAS_LOG{"HAS_LOG<br/>له سجل"}
    WRITES_LOG{"WRITES_LOG<br/>ينفذ إجراء"}

    %% الربط والتعددية (Connections & Cardinality)
    REPORTS ---|1| HAS_IMAGE
    HAS_IMAGE ---|N| REPORT_IMAGES

    USERS ---|1| UPLOADS
    UPLOADS ---|N| REPORT_IMAGES

    REPORTS ---|1| HAS_LOG
    HAS_LOG ---|N| REPORT_LOGS

    USERS ---|1| WRITES_LOG
    WRITES_LOG ---|N| REPORT_LOGS

    %% التنسيق والألوان (Styling)
    classDef entity fill:#DCEBFA,stroke:#34495E,stroke-width:1.5px,color:#000;
    classDef relationship fill:#BFCAD3,stroke:#34495E,stroke-width:1.5px,color:#000;

    class USERS,REPORTS,REPORT_IMAGES,REPORT_LOGS entity;
    class HAS_IMAGE,UPLOADS,HAS_LOG,WRITES_LOG relationship;
----------------------------------------------------------------------------------
flowchart LR

    %% الكيانات (Entities)
    USERS["USERS<br/>المستخدمون"]
    SUGGESTIONS["SUGGESTIONS<br/>المقترحات"]
    SUGGESTION_VOTES["SUGGESTION_VOTES<br/>تصويتات المقترحات"]

    %% العلاقات (Relationships)
    CREATES_SUGGESTION{"CREATES<br/>ينشئ"}
    REVIEWS_SUGGESTION{"REVIEWS<br/>يراجع"}
    HAS_SUGGESTION_VOTE{"HAS_VOTE<br/>له تصويت"}
    VOTES_SUGGESTION{"VOTES<br/>يصوت"}

    %% الربط والتعددية (Connections & Cardinality)
    USERS ---|1| CREATES_SUGGESTION
    CREATES_SUGGESTION ---|N| SUGGESTIONS

    USERS ---|1| REVIEWS_SUGGESTION
    REVIEWS_SUGGESTION ---|N| SUGGESTIONS

    SUGGESTIONS ---|1| HAS_SUGGESTION_VOTE
    HAS_SUGGESTION_VOTE ---|N| SUGGESTION_VOTES

    USERS ---|1| VOTES_SUGGESTION
    VOTES_SUGGESTION ---|N| SUGGESTION_VOTES

    %% التنسيق والألوان وحجم الخط المطلوب (Styling & Font Sizes)
    classDef entity fill:#DCEBFA,stroke:#34495E,stroke-width:1.5px,color:#000,font-size:18px;
    classDef relationship fill:#BFCAD3,stroke:#34495E,stroke-width:1.5px,color:#000,font-size:12px;

    class USERS,SUGGESTIONS,SUGGESTION_VOTES entity;
    class CREATES_SUGGESTION,REVIEWS_SUGGESTION,HAS_SUGGESTION_VOTE,VOTES_SUGGESTION relationship;
-----------------------------------------------------------------------------------
flowchart LR

    %% الكيانات (Entities)
    USERS["USERS<br/>المستخدمون"]
    NOTIFICATIONS["NOTIFICATIONS<br/>الإشعارات"]
    SECURITY_LOGS["SECURITY_LOGS<br/>السجلات الأمنية"]
    PERSONAL_ACCESS_TOKENS["PERSONAL_ACCESS_TOKENS<br/>رموز الدخول"]
    PENDING_REGISTRATIONS["PENDING_REGISTRATIONS<br/>التسجيلات المعلقة"]

    %% العلاقات (Relationships)
    RECEIVES_NOTIFICATION{"RECEIVES<br/>يستقبل"}
    HAS_SECURITY_LOG{"HAS_SECURITY_LOG<br/>له سجل أمني"}
    HAS_TOKEN{"HAS_TOKEN<br/>له رمز دخول"}
    HAS_PENDING_REGISTRATION{"HAS_PENDING_REGISTRATION<br/>له تسجيل معلق"}

    %% الربط والتعددية (Connections & Cardinality)
    USERS ---|1| RECEIVES_NOTIFICATION
    RECEIVES_NOTIFICATION ---|N| NOTIFICATIONS

    USERS ---|1| HAS_SECURITY_LOG
    HAS_SECURITY_LOG ---|N| SECURITY_LOGS

    USERS ---|1| HAS_TOKEN
    HAS_TOKEN ---|N| PERSONAL_ACCESS_TOKENS

    USERS ---|"0..1"| HAS_PENDING_REGISTRATION
    HAS_PENDING_REGISTRATION ---|1| PENDING_REGISTRATIONS

    %% التنسيق والألوان وحجم الخط المطلوب (Styling & Font Sizes)
    classDef entity fill:#DCEBFA,stroke:#34495E,stroke-width:1.5px,color:#000,font-size:18px;
    classDef relationship fill:#BFCAD3,stroke:#34495E,stroke-width:1.5px,color:#000,font-size:12px;

    class USERS,NOTIFICATIONS,SECURITY_LOGS,PERSONAL_ACCESS_TOKENS,PENDING_REGISTRATIONS entity;
    class RECEIVES_NOTIFICATION,HAS_SECURITY_LOG,HAS_TOKEN,HAS_PENDING_REGISTRATION relationship;
-----------------------------------------------------------------------------------
flowchart LR

    %% الكيانات (Entities)
    USERS["USERS<br/>المستخدمون"]
    AREAS["AREAS<br/>المناطق"]
    EMERGENCY_CONTACTS["EMERGENCY_CONTACTS<br/>أرقام الطوارئ"]
    PUBLIC_FACILITIES["PUBLIC_FACILITIES<br/>المرافق العامة"]
    CURRENT_PROJECTS["CURRENT_PROJECTS<br/>المشاريع الحالية"]

    %% العلاقات (Relationships)
    ADDS_EMERGENCY{"ADDS<br/>يضيف"}
    ADDS_FACILITY{"ADDS<br/>يضيف"}
    ADDS_PROJECT{"ADDS<br/>يضيف"}
    PROJECT_AREA{"LOCATED_IN<br/>يقع في"}

    %% الربط والتعددية (Connections & Cardinality)
    USERS ---|1| ADDS_EMERGENCY
    ADDS_EMERGENCY ---|N| EMERGENCY_CONTACTS

    USERS ---|1| ADDS_FACILITY
    ADDS_FACILITY ---|N| PUBLIC_FACILITIES

    USERS ---|1| ADDS_PROJECT
    ADDS_PROJECT ---|N| CURRENT_PROJECTS

    AREAS ---|1| PROJECT_AREA
    PROJECT_AREA ---|N| CURRENT_PROJECTS

    %% التنسيق والألوان وحجم الخط المطلوب (Styling & Font Sizes)
    classDef entity fill:#DCEBFA,stroke:#34495E,stroke-width:1.5px,color:#000,font-size:18px;
    classDef relationship fill:#BFCAD3,stroke:#34495E,stroke-width:1.5px,color:#000,font-size:12px;

    class USERS,AREAS,EMERGENCY_CONTACTS,PUBLIC_FACILITIES,CURRENT_PROJECTS entity;
    class ADDS_EMERGENCY,ADDS_FACILITY,ADDS_PROJECT,PROJECT_AREA relationship;
-----------------------------------------------------------------------------------
flowchart LR

    %% الكيانات (Entities)
    USERS["USERS<br/>المستخدمون"]
    REPORTS["REPORTS<br/>البلاغات"]
    REPORT_COMMENTS["REPORT_COMMENTS<br/>تعليقات البلاغ"]
    REPORT_VOTES["REPORT_VOTES<br/>تصويتات البلاغ"]
    RATINGS["RATINGS<br/>تقييمات البلاغ"]

    %% العلاقات (Relationships)
    HAS_COMMENT{"HAS_COMMENT<br/>له تعليق"}
    WRITES{"WRITES<br/>يكتب"}
    HAS_VOTE{"HAS_VOTE<br/>له تصويت"}
    VOTES{"VOTES<br/>يصوت"}
    HAS_RATING{"HAS_RATING<br/>له تقييم"}
    RATES{"RATES<br/>يقيم"}

    %% الربط والتعددية (Connections & Cardinality)
    REPORTS ---|1| HAS_COMMENT
    HAS_COMMENT ---|N| REPORT_COMMENTS

    USERS ---|1| WRITES
    WRITES ---|N| REPORT_COMMENTS

    REPORTS ---|1| HAS_VOTE
    HAS_VOTE ---|N| REPORT_VOTES

    USERS ---|1| VOTES
    VOTES ---|N| REPORT_VOTES

    REPORTS ---|1| HAS_RATING
    HAS_RATING ---|N| RATINGS

    USERS ---|1| RATES
    RATES ---|N| RATINGS

    %% التنسيق والألوان (Styling)
    classDef entity fill:#DCEBFA,stroke:#34495E,stroke-width:1.5px,color:#000;
    classDef relationship fill:#BFCAD3,stroke:#34495E,stroke-width:1.5px,color:#000;

    class USERS,REPORTS,REPORT_COMMENTS,REPORT_VOTES,RATINGS entity;
    class HAS_COMMENT,WRITES,HAS_VOTE,VOTES,HAS_RATING,RATES relationship;