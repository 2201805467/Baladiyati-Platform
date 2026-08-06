flowchart LR

    %% الكيانات (Entities)
    USERS["USER<br/>المستخدم"]
    COMMUNITY_INITIATIVES["COMMUNITY_INITIATIVE<br/>المبادرة والحملة"]
    INITIATIVE_REGISTRATIONS["INITIATIVE_REGISTRATION<br/>تسجيل المبادرة"]
    NOTIFICATIONS["NOTIFICATION<br/>الإشعار"]

    %% العلاقات (Relationships)
    CREATES_INITIATIVE{"CREATES<br/>ينشئ"}
    REGISTERS_IN{"REGISTERS_IN<br/>يسجل في"}
    HAS_REGISTRATION{"HAS_REGISTRATION<br/>له تسجيل"}
    CONFIRMS_ATTENDANCE{"CONFIRMS_ATTENDANCE<br/>يؤكد الحضور"}
    SENDS_INITIATIVE_NOTIFICATION{"SENDS_NOTIFICATION<br/>يرسل إشعار"}

    %% الربط والتعددية (Connections & Cardinality)
    USERS ---|1| CREATES_INITIATIVE
    CREATES_INITIATIVE ---|N| COMMUNITY_INITIATIVES

    USERS ---|1| REGISTERS_IN
    REGISTERS_IN ---|N| INITIATIVE_REGISTRATIONS

    COMMUNITY_INITIATIVES ---|1| HAS_REGISTRATION
    HAS_REGISTRATION ---|N| INITIATIVE_REGISTRATIONS

    USERS ---|1| CONFIRMS_ATTENDANCE
    CONFIRMS_ATTENDANCE ---|N| INITIATIVE_REGISTRATIONS

    COMMUNITY_INITIATIVES ---|1| SENDS_INITIATIVE_NOTIFICATION
    SENDS_INITIATIVE_NOTIFICATION ---|N| NOTIFICATIONS

    %% التنسيق والألوان (Styling)
    classDef entity fill:#DCEBFA,stroke:#34495E,stroke-width:1.5px,color:#000;
    classDef relationship fill:#BFCAD3,stroke:#34495E,stroke-width:1.5px,color:#000;

    class USERS,COMMUNITY_INITIATIVES,INITIATIVE_REGISTRATIONS,NOTIFICATIONS entity;
    class CREATES_INITIATIVE,REGISTERS_IN,HAS_REGISTRATION,CONFIRMS_ATTENDANCE,SENDS_INITIATIVE_NOTIFICATION relationship;

----------------------------------------------------------------------------------
flowchart LR

    %% الكيانات (Entities)
    USERS["USER<br/>المستخدم"]
    GEO_BROADCASTS["GEO_BROADCAST<br/>التنبيه الجغرافي"]
    GEO_BROADCAST_RECIPIENTS["GEO_BROADCAST_RECIPIENT<br/>مستلم التنبيه"]
    NOTIFICATIONS["NOTIFICATION<br/>الإشعار"]

    %% العلاقات (Relationships)
    CREATES_BROADCAST{"CREATES<br/>ينشئ"}
    TARGETS_USER{"TARGETS<br/>يستهدف"}
    HAS_RECIPIENT{"HAS_RECIPIENT<br/>له مستلم"}
    RECEIVES_BROADCAST{"RECEIVES<br/>يستقبل"}
    GENERATES_NOTIFICATION{"GENERATES_NOTIFICATION<br/>ينتج إشعار"}

    %% الربط والتعددية (Connections & Cardinality)
    USERS ---|1| CREATES_BROADCAST
    CREATES_BROADCAST ---|N| GEO_BROADCASTS

    GEO_BROADCASTS ---|1| HAS_RECIPIENT
    HAS_RECIPIENT ---|N| GEO_BROADCAST_RECIPIENTS

    USERS ---|1| RECEIVES_BROADCAST
    RECEIVES_BROADCAST ---|N| GEO_BROADCAST_RECIPIENTS

    GEO_BROADCASTS ---|1| TARGETS_USER
    TARGETS_USER ---|N| USERS

    GEO_BROADCAST_RECIPIENTS ---|"0..1"| GENERATES_NOTIFICATION
    GENERATES_NOTIFICATION ---|1| NOTIFICATIONS

    %% التنسيق والألوان (Styling)
    classDef entity fill:#DCEBFA,stroke:#34495E,stroke-width:1.5px,color:#000;
    classDef relationship fill:#BFCAD3,stroke:#34495E,stroke-width:1.5px,color:#000;

    class USERS,GEO_BROADCASTS,GEO_BROADCAST_RECIPIENTS,NOTIFICATIONS entity;
    class CREATES_BROADCAST,TARGETS_USER,HAS_RECIPIENT,RECEIVES_BROADCAST,GENERATES_NOTIFICATION relationship;

----------------------------------------------------------------------------------
flowchart LR

    %% الكيانات (Entities)
    USERS["USER<br/>المستخدم"]
    LOST_FOUND_ITEMS["LOST_FOUND_ITEM<br/>منشور المفقودات والموجودات"]
    LOST_FOUND_COMMENTS["LOST_FOUND_COMMENT<br/>التعليق العام"]
    LOST_FOUND_CHAT_THREADS["LOST_FOUND_CHAT_THREAD<br/>غرفة الدردشة الخاصة"]
    LOST_FOUND_CHAT_MESSAGES["LOST_FOUND_CHAT_MESSAGE<br/>رسالة الدردشة"]
    LOST_FOUND_ABUSE_REPORTS["LOST_FOUND_ABUSE_REPORT<br/>بلاغ الإساءة"]

    %% العلاقات (Relationships)
    PUBLISHES_ITEM{"PUBLISHES<br/>ينشر"}
    MODERATES_ITEM{"MODERATES<br/>يراقب أو يحذف"}
    HAS_PUBLIC_COMMENT{"HAS_COMMENT<br/>له تعليق عام"}
    WRITES_LOST_COMMENT{"WRITES<br/>يكتب"}
    HAS_CHAT_THREAD{"HAS_CHAT_THREAD<br/>له غرفة دردشة"}
    THREAD_PUBLISHER{"THREAD_PUBLISHER<br/>طرف الناشر"}
    THREAD_INTERESTED{"THREAD_INTERESTED<br/>طرف مهتم"}
    HAS_CHAT_MESSAGE{"HAS_MESSAGE<br/>له رسالة"}
    SENDS_CHAT_MESSAGE{"SENDS<br/>يرسل"}
    REPORTS_ABUSE{"REPORTS_ABUSE<br/>يبلغ عن إساءة"}
    REVIEWS_ABUSE{"REVIEWS_ABUSE<br/>يراجع الإساءة"}

    %% الربط والتعددية (Connections & Cardinality)
    USERS ---|1| PUBLISHES_ITEM
    PUBLISHES_ITEM ---|N| LOST_FOUND_ITEMS

    USERS ---|"0..1"| MODERATES_ITEM
    MODERATES_ITEM ---|N| LOST_FOUND_ITEMS

    LOST_FOUND_ITEMS ---|1| HAS_PUBLIC_COMMENT
    HAS_PUBLIC_COMMENT ---|N| LOST_FOUND_COMMENTS

    USERS ---|1| WRITES_LOST_COMMENT
    WRITES_LOST_COMMENT ---|N| LOST_FOUND_COMMENTS

    LOST_FOUND_ITEMS ---|1| HAS_CHAT_THREAD
    HAS_CHAT_THREAD ---|N| LOST_FOUND_CHAT_THREADS

    USERS ---|1| THREAD_PUBLISHER
    THREAD_PUBLISHER ---|N| LOST_FOUND_CHAT_THREADS

    USERS ---|1| THREAD_INTERESTED
    THREAD_INTERESTED ---|N| LOST_FOUND_CHAT_THREADS

    LOST_FOUND_CHAT_THREADS ---|1| HAS_CHAT_MESSAGE
    HAS_CHAT_MESSAGE ---|N| LOST_FOUND_CHAT_MESSAGES

    USERS ---|1| SENDS_CHAT_MESSAGE
    SENDS_CHAT_MESSAGE ---|N| LOST_FOUND_CHAT_MESSAGES

    USERS ---|1| REPORTS_ABUSE
    REPORTS_ABUSE ---|N| LOST_FOUND_ABUSE_REPORTS

    USERS ---|"0..1"| REVIEWS_ABUSE
    REVIEWS_ABUSE ---|N| LOST_FOUND_ABUSE_REPORTS

    %% التنسيق والألوان (Styling)
    classDef entity fill:#DCEBFA,stroke:#34495E,stroke-width:1.5px,color:#000;
    classDef relationship fill:#BFCAD3,stroke:#34495E,stroke-width:1.5px,color:#000;

    class USERS,LOST_FOUND_ITEMS,LOST_FOUND_COMMENTS,LOST_FOUND_CHAT_THREADS,LOST_FOUND_CHAT_MESSAGES,LOST_FOUND_ABUSE_REPORTS entity;
    class PUBLISHES_ITEM,MODERATES_ITEM,HAS_PUBLIC_COMMENT,WRITES_LOST_COMMENT,HAS_CHAT_THREAD,THREAD_PUBLISHER,THREAD_INTERESTED,HAS_CHAT_MESSAGE,SENDS_CHAT_MESSAGE,REPORTS_ABUSE,REVIEWS_ABUSE relationship;

----------------------------------------------------------------------------------
flowchart LR

    %% الكيانات (Entities)
    USERS["USER<br/>المستخدم"]
    DEPARTMENTS["DEPARTMENT<br/>القسم"]
    REPORTS["REPORT<br/>البلاغ"]
    REPORT_IMAGES["REPORT_IMAGE<br/>صورة البلاغ"]
    REPORT_LOGS["REPORT_LOG<br/>سجل حركة البلاغ"]
    REPORT_COMMENTS["REPORT_COMMENT<br/>تعليق البلاغ"]

    %% العلاقات (Relationships)
    BELONGS_TO_DEPARTMENT{"BELONGS_TO<br/>ينتمي إلى قسم"}
    HANDLES_REPORT{"HANDLES<br/>يعالج"}
    STARTS_FIELD_WORK{"STARTS_FIELD_WORK<br/>يبدأ العمل الميداني"}
    FINISHES_FIELD_WORK{"FINISHES_FIELD_WORK<br/>ينهي العمل الميداني"}
    UPLOADS_BEFORE_AFTER{"UPLOADS_BEFORE_AFTER<br/>يرفع صورة قبل/بعد"}
    WRITES_FIELD_LOG{"WRITES_LOG<br/>يسجل إجراء"}
    WRITES_FIELD_COMMENT{"WRITES_COMMENT<br/>يرد على المواطن"}

    %% الربط والتعددية (Connections & Cardinality)
    USERS ---|"0..1"| BELONGS_TO_DEPARTMENT
    BELONGS_TO_DEPARTMENT ---|1| DEPARTMENTS

    DEPARTMENTS ---|1| HANDLES_REPORT
    HANDLES_REPORT ---|N| REPORTS

    USERS ---|1| STARTS_FIELD_WORK
    STARTS_FIELD_WORK ---|N| REPORTS

    USERS ---|1| FINISHES_FIELD_WORK
    FINISHES_FIELD_WORK ---|N| REPORTS

    USERS ---|1| UPLOADS_BEFORE_AFTER
    UPLOADS_BEFORE_AFTER ---|N| REPORT_IMAGES

    REPORTS ---|1| UPLOADS_BEFORE_AFTER
    UPLOADS_BEFORE_AFTER ---|N| REPORT_IMAGES

    USERS ---|1| WRITES_FIELD_LOG
    WRITES_FIELD_LOG ---|N| REPORT_LOGS

    REPORTS ---|1| WRITES_FIELD_LOG
    WRITES_FIELD_LOG ---|N| REPORT_LOGS

    USERS ---|1| WRITES_FIELD_COMMENT
    WRITES_FIELD_COMMENT ---|N| REPORT_COMMENTS

    REPORTS ---|1| WRITES_FIELD_COMMENT
    WRITES_FIELD_COMMENT ---|N| REPORT_COMMENTS

    %% التنسيق والألوان (Styling)
    classDef entity fill:#DCEBFA,stroke:#34495E,stroke-width:1.5px,color:#000;
    classDef relationship fill:#BFCAD3,stroke:#34495E,stroke-width:1.5px,color:#000;

    class USERS,DEPARTMENTS,REPORTS,REPORT_IMAGES,REPORT_LOGS,REPORT_COMMENTS entity;
    class BELONGS_TO_DEPARTMENT,HANDLES_REPORT,STARTS_FIELD_WORK,FINISHES_FIELD_WORK,UPLOADS_BEFORE_AFTER,WRITES_FIELD_LOG,WRITES_FIELD_COMMENT relationship;

----------------------------------------------------------------------------------
flowchart LR

    %% الكيانات (Entities)
    USERS["USER<br/>المستخدم"]
    DEPARTMENTS["DEPARTMENT<br/>القسم"]
    POLLS["POLL<br/>استطلاع الرأي"]
    POLL_OPTIONS["POLL_OPTION<br/>خيار الاستطلاع"]
    POLL_VOTES["POLL_VOTE<br/>تصويت الاستطلاع"]
    POLL_RECIPIENTS["POLL_RECIPIENT<br/>مستلم الاستطلاع"]
    NOTIFICATIONS["NOTIFICATION<br/>الإشعار"]

    %% العلاقات (Relationships)
    CREATES_POLL{"CREATES<br/>ينشئ"}
    RELATED_TO_DEPARTMENT{"RELATED_TO<br/>مرتبط بقسم"}
    HAS_OPTION{"HAS_OPTION<br/>له خيار"}
    HAS_POLL_VOTE{"HAS_VOTE<br/>له تصويت"}
    SELECTS_OPTION{"SELECTS_OPTION<br/>يختار خيار"}
    VOTES_IN_POLL{"VOTES<br/>يصوت"}
    HAS_POLL_RECIPIENT{"HAS_RECIPIENT<br/>له مستلم"}
    RECEIVES_POLL{"RECEIVES<br/>يستقبل"}
    POLL_NOTIFICATION{"GENERATES_NOTIFICATION<br/>ينتج إشعار"}

    %% الربط والتعددية (Connections & Cardinality)
    USERS ---|1| CREATES_POLL
    CREATES_POLL ---|N| POLLS

    DEPARTMENTS ---|"0..1"| RELATED_TO_DEPARTMENT
    RELATED_TO_DEPARTMENT ---|N| POLLS

    POLLS ---|1| HAS_OPTION
    HAS_OPTION ---|N| POLL_OPTIONS

    POLLS ---|1| HAS_POLL_VOTE
    HAS_POLL_VOTE ---|N| POLL_VOTES

    POLL_OPTIONS ---|1| SELECTS_OPTION
    SELECTS_OPTION ---|N| POLL_VOTES

    USERS ---|1| VOTES_IN_POLL
    VOTES_IN_POLL ---|N| POLL_VOTES

    POLLS ---|1| HAS_POLL_RECIPIENT
    HAS_POLL_RECIPIENT ---|N| POLL_RECIPIENTS

    USERS ---|1| RECEIVES_POLL
    RECEIVES_POLL ---|N| POLL_RECIPIENTS

    POLL_RECIPIENTS ---|"0..1"| POLL_NOTIFICATION
    POLL_NOTIFICATION ---|1| NOTIFICATIONS

    %% التنسيق والألوان (Styling)
    classDef entity fill:#DCEBFA,stroke:#34495E,stroke-width:1.5px,color:#000;
    classDef relationship fill:#BFCAD3,stroke:#34495E,stroke-width:1.5px,color:#000;

    class USERS,DEPARTMENTS,POLLS,POLL_OPTIONS,POLL_VOTES,POLL_RECIPIENTS,NOTIFICATIONS entity;
    class CREATES_POLL,RELATED_TO_DEPARTMENT,HAS_OPTION,HAS_POLL_VOTE,SELECTS_OPTION,VOTES_IN_POLL,HAS_POLL_RECIPIENT,RECEIVES_POLL,POLL_NOTIFICATION relationship;
