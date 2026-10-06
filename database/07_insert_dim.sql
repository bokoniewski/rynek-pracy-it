-- =============================================================================
-- SKRYPT: Dane do tabel dim – warstwa GOLD
-- PROJEKT: Project_job
-- OPIS: Gotowe inserty dla tabel D_ (wymiary)
-- KOLEJNOŚĆ WYKONANIA: 5
-- ZALEŻNOŚCI: 01_schemas.sql, 04_gold_tables.sql, 05_create_procedure_function.sql
-- =============================================================================



-- -----------------------------------------------------------------------------
-- Tabela: gold.D_CONTRACT
-- OPIS:   Rodzaj umowy
--- -----------------------------------------------------------------------------

INSERT INTO gold.D_CONTRACT (contract_name) VALUES
    ('B2B'),
    ('UoP'),
    ('Umowa zlecenie'),
    ('Umowa na zastępstwo'),
	('Umowa o dzieło'),
	('Umowa o staż')
ON CONFLICT (contract_name) DO NOTHING;



-- -----------------------------------------------------------------------------
-- Tabela: gold.D_DATE
-- OPIS:   Dodanie daty za cały rok + przyszły
-- -----------------------------------------------------------------------------
CALL gold.load_d_date();



--- -----------------------------------------------------------------------------
-- Tabela: gold.D_LEVEL
-- OPIS:   Rodzaj stanowiska
--- -----------------------------------------------------------------------------


INSERT INTO gold.D_LEVEL (level_name) VALUES
	('Trainee'),
    ('Junior'),
    ('Mid'),
    ('Senior'),
    ('Expert'),
    ('Manager'),
	('Lead'),
    ('Director')
ON CONFLICT (level_name) DO NOTHING;



-- -----------------------------------------------------------------------------
-- Tabela: gold.D_LOCATION
-- OPIS:   Miasta Polski powyżej 50 000 mieszkańców
-- 		   Wzorce LIKE do dopasowania z silver.offer_locations
-- -----------------------------------------------------------------------------

INSERT INTO gold.d_location (city, region, country, like_patterns) VALUES
('Warszawa',                'mazowieckie',              'PL', '["warszawa%", "warsaw%"]'),
('Kraków',                  'małopolskie',               'PL', '["krakow%", "cracow%", "cracov%"]'),
('�ódź',                    'łódzkie',                   'PL', '["lodz%"]'),
('Wrocław',                 'dolnośląskie',              'PL', '["wroclaw%"]'),
('Poznań',                  'wielkopolskie',             'PL', '["poznan%"]'),
('Gdańsk',                  'pomorskie',                 'PL', '["gdansk%", "trojmiasto%"]'),
('Szczecin',                'zachodniopomorskie',        'PL', '["szczecin%"]'),
('Bydgoszcz',               'kujawsko-pomorskie',        'PL', '["bydgoszcz%"]'),
('Lublin',                  'lubelskie',                 'PL', '["lublin%"]'),
('Białystok',               'podlaskie',                 'PL', '["bialystok%"]'),
('Katowice',                'śląskie',                   'PL', '["katowice%", "silesian%"]'),
('Gdynia',                  'pomorskie',                 'PL', '["gdynia%"]'),
('Częstochowa',             'śląskie',                   'PL', '["czestochowa%"]'),
('Rzeszów',                 'podkarpackie',              'PL', '["rzeszow%"]'),
('Radom',                   'mazowieckie',               'PL', '["radom%"]'),
('Toruń',                   'kujawsko-pomorskie',        'PL', '["torun%"]'),
('Sosnowiec',               'śląskie',                   'PL', '["sosnowiec%"]'),
('Kielce',                  'świętokrzyskie',            'PL', '["kielce%"]'),
('Gliwice',                 'śląskie',                   'PL', '["gliwice%"]'),
('Olsztyn',                 'warmińsko-mazurskie',       'PL', '["olsztyn%"]'),
('Bielsko-Biała',           'śląskie',                   'PL', '["bielsko%"]'),
('Zabrze',                  'śląskie',                   'PL', '["zabrze%"]'),
('Bytom',                   'śląskie',                   'PL', '["bytom%"]'),
('Zielona Góra',            'lubuskie',                  'PL', '["zielona gora%"]'),
('Rybnik',                  'śląskie',                   'PL', '["rybnik%"]'),
('Ruda Śląska',             'śląskie',                   'PL', '["ruda slaska%"]'),
('Opole',                   'opolskie',                  'PL', '["opole%"]'),
('Tychy',                   'śląskie',                   'PL', '["tychy%"]'),
('Gorzów Wielkopolski',     'lubuskie',                  'PL', '["gorzow%"]'),
('Dąbrowa Górnicza',        'śląskie',                   'PL', '["dabrowa gornicza%"]'),
('Elbląg',                  'warmińsko-mazurskie',       'PL', '["elblag%"]'),
('Płock',                   'mazowieckie',               'PL', '["plock%"]'),
('Wałbrzych',               'dolnośląskie',              'PL', '["walbrzych%"]'),
('Chorzów',                 'śląskie',                   'PL', '["chorzow%"]'),
('Tarnów',                  'małopolskie',               'PL', '["tarnow%"]'),
('Kalisz',                  'wielkopolskie',             'PL', '["kalisz%"]'),
('Włocławek',               'kujawsko-pomorskie',        'PL', '["wloclawek%"]'),
('Legnica',                 'dolnośląskie',              'PL', '["legnica%"]'),
('Grudziądz',               'kujawsko-pomorskie',        'PL', '["grudziadz%"]'),
('Jaworzno',                'śląskie',                   'PL', '["jaworzno%"]'),
('Słupsk',                  'pomorskie',                 'PL', '["slupsk%"]'),
('Jastrzębie-Zdrój',        'śląskie',                   'PL', '["jastrzebie%"]'),
('Nowy Sącz',               'małopolskie',               'PL', '["nowy sacz%"]'),
('Jelenia Góra',            'dolnośląskie',              'PL', '["jelenia gora%"]'),
('Siedlce',                 'mazowieckie',               'PL', '["siedlce%"]'),
('Mysłowice',               'śląskie',                   'PL', '["myslowice%"]'),
('Konin',                   'wielkopolskie',             'PL', '["konin%"]'),
('Piła',                    'wielkopolskie',             'PL', '["pila%"]'),
('Piotrków Trybunalski',    'łódzkie',                   'PL', '["piotrkow%"]'),
('Inowrocław',              'kujawsko-pomorskie',        'PL', '["inowroclaw%"]'),
('Lubin',                   'dolnośląskie',              'PL', '["lubin%"]'),
('Ostrów Wielkopolski',     'wielkopolskie',             'PL', '["ostrow wielkopolski%"]'),
('Suwałki',                 'podlaskie',                 'PL', '["suwalki%"]'),
('Stargard',                'zachodniopomorskie',        'PL', '["stargard%"]'),
('Gniezno',                 'wielkopolskie',             'PL', '["gniezno%"]'),
('Ostrowiec Świętokrzyski', 'świętokrzyskie',            'PL', '["ostrowiec%"]'),
('Siemianowice Śląskie',    'śląskie',                   'PL', '["siemianowice%"]'),
('Głogów',                  'dolnośląskie',              'PL', '["glogow%"]'),
('Pabianice',               'łódzkie',                   'PL', '["pabianice%"]'),
('Leszno',                  'wielkopolskie',             'PL', '["leszno%"]'),
('Żory',                    'śląskie',                   'PL', '["zory%"]'),
('Zamość',                  'lubelskie',                 'PL', '["zamosc%"]'),
('Pruszków',                'mazowieckie',               'PL', '["pruszkow%"]'),
('�omża',                   'podlaskie',                 'PL', '["lomza%"]'),
('Ełk',                     'warmińsko-mazurskie',       'PL', '["elk", "%ełk%"]'),
('Tomaszów Mazowiecki',     'łódzkie',                   'PL', '["tomaszow mazowiecki%"]'),
('Chełm',                   'lubelskie',                 'PL', '["chelm%"]'),
('Mielec',                  'podkarpackie',              'PL', '["mielec%"]'),
('Kędzierzyn-Koźle',        'opolskie',                  'PL', '["kedzierzyn%"]'),
('Przemyśl',                'podkarpackie',              'PL', '["przemysl%"]'),
('Stalowa Wola',            'podkarpackie',              'PL', '["stalowa wola%"]'),
('Tczew',                   'pomorskie',                 'PL', '["tczew%"]'),
('Biała Podlaska',          'lubelskie',                 'PL', '["biala podlaska%"]'),
('Bełchatów',               'łódzkie',                   'PL', '["belchatow%"]'),
('Świdnica',                'dolnośląskie',              'PL', '["swidnica%"]'),
('Będzin',                  'śląskie',                   'PL', '["bedzin%"]'),
('Zgierz',                  'łódzkie',                   'PL', '["zgierz%"]'),
('Piekary Śląskie',         'śląskie',                   'PL', '["piekary%"]'),
('Legionowo',               'mazowieckie',               'PL', '["legionowo%"]')

ON CONFLICT (city) DO UPDATE SET like_patterns = EXCLUDED.like_patterns;





--- -----------------------------------------------------------------------------
-- Tabela: gold.D_MODE
-- OPIS: Miejsce wykonywania pracy
--- -----------------------------------------------------------------------------

INSERT INTO gold.D_MODE (mode_name) VALUES
    ('Zdalnie'),
    ('Hybrydowo'),
    ('Biuro'),
	('W terenie')
ON CONFLICT (mode_name) DO NOTHING;



-- -----------------------------------------------------------------------------
-- Tabela: gold.D_REQUIREMENT_TYPE
-- OPIS:   Rodzaj wymagania
--- -----------------------------------------------------------------------------

INSERT INTO gold.D_REQUIREMENT_TYPE (requirement_type_name) VALUES
    ('wymagane'),
    ('opcjonalne')
ON CONFLICT (requirement_type_name) DO NOTHING;



--- -----------------------------------------------------------------------------
-- Tabela: gold.D_SPECS
-- OPIS: Słownik kategorii specjalizacji z aliasami i priorytetami
-- priority: 1 = najwyższy priorytet przy remisie scoringu
-- spec_aliases: lista wartości z silver.offer_specs które pasują do tej kategorii
--- -----------------------------------------------------------------------------

INSERT INTO gold.D_SPECS (spec_name, priority, spec_aliases) VALUES
('Fullstack',           10,  '["Full-stack", "Fullstack"]'),
('Security',            20,  '["Security", "Keycloak"]'),
('Game Dev',            30,  '["Game dev", "Game"]'),
('AI/ML',               40,  '["AI", "AI/ML"]'),
('ERP/SAP',             50,  '["ERP", "SAP", "Microsoft Dynamics", "Microsoft Dynamics 365", "IBM"]'),
('Embedded',            60,  '["Embedded", "C", "C++"]'),
('UX/UI & Design',      70,  '["UX/UI", "Design"]'),
('Architecture',        80,  '["Architecture", "System analytics", "UML"]'),
('Mobile',              90,  '["Mobile", "Android", "iOS", "Flutter", "React native"]'),
('QA/Testing',          100, '["QA/Testing", "Testing", "Selenium", "Jira", "Postman"]'),
('Backend',             110, '["Backend", "Java", "Python", "Node.js", "PHP", "Ruby", "Scala", "Kotlin", "Go", "Golang", "Rust", "C#", ".NET", "Net", "Spring", "Ruby on Rails"]'),
('Frontend',            120, '["Frontend", "JavaScript", "TypeScript", "React", "Angular", "Vue.js", "HTML"]'),
('DevOps & Cloud',      130, '["DevOps", "Cloud", "AWS", "Azure", "Kubernetes", "Linux", "Ansible", "GCP", "Terraform", "Jenkins", "GitLab", "Azure Data Factory"]'),
('IT Admin',            140, '["IT admin", "Admin", "Sys. Administrator", "Helpdesk", "Support", "Linux", "ServiceNow"]'),
('Business Analysis',   150, '["Business analytics", "Business Analysis", "Business Intelligence", "UML", "Analytics", "Power Platform"]'),
('Data & BI',           160, '["Data", "BI", "Data analytics", "Big Data / Data Science", "Analytics", "SQL", "Spark", "Hadoop", "Kafka", "Snowflake", "Databricks", "Azure Data", "Business Intelligence", "Oracle", "GCP", 	"Flink", "Azure Data Factory"]'),
('Project Management',  170, '["Project Management", "Project Manager", "PM", "Agile", "Product Management", "Jira"]'),
('Other',               180, '["Other", "Inne IT", "Salesforce", "macOS"]')
ON CONFLICT (spec_name) DO UPDATE SET spec_aliases = EXCLUDED.spec_aliases;





-- -----------------------------------------------------------------------------
-- Tabela: gold.D_TECHNOLOGY
-- OPIS: Słownik technologii z wzorcami LIKE do dopasowania z silver.offer_technologies
--- -----------------------------------------------------------------------------

INSERT INTO gold.D_TECHNOLOGY (tech_name, like_patterns) VALUES
('Python', '["%python%", "%celery%"]'),
('Java', '["%java%"]'),
('JavaScript', '["%javascript%", "%java script%", "%rxjs%", "%ngrx%", "%jquery%", "%bootstrap%", "%express%"]'),
('TypeScript', '["%typescript%", "%type script%"]'),
('C#', '["%c#%"]'),
('C++', '["%c++%", "%c/c++%", "%c++17%"]'),
('Go', '["%golang%", "% go %", "go"]'),
('Kotlin', '["%kotlin%"]'),
('Swift', '["%swift%"]'),
('Ruby', '["%ruby%"]'),
('PHP', '["%php%"]'),
('Scala', '["%scala%"]'),
('Rust', '["%rust%"]'),
('R', '["% r %", "r"]'),
('Perl', '["%perl%"]'),
('Dart', '["%dart%"]'),
('Elixir', '["%elixir%"]'),
('Groovy', '["%groovy%"]'),
('Objective-C', '["%objective-c%"]'),
('.NET', '["%.net%", "%dotnet%"]'),
('ABAP', '["%abap%"]'),
('VBA', '["%vba%"]'),
('Shell/Bash', '["%bash%", "%shell%", "%powershell%"]'),
('C', '["c", " c ", "embedded c"]'),
('React', '["%react%"]'),
('Angular', '["%angular%"]'),
('Vue.js', '["%vue%"]'),
('HTML', '["%html%"]'),
('CSS', '["%css%", "%scss%", "%sass%", "%tailwind%", "%less%"]'),
('Next.js', '["%next.js%", "%nextjs%"]'),
('Node.js', '["%node.js%", "%nodejs%"]'),
('Spring', '["%spring%", "%quarkus%"]'),
('Django', '["%django%"]'),
('FastAPI', '["%fastapi%", "%fast api%"]'),
('Flask', '["%flask%"]'),
('Laravel', '["%laravel%"]'),
('Symfony', '["%symfony%"]'),
('ASP.NET', '["%asp.net%", "%wcf%", "%wpf%", "%blazor%", "%winforms%", "%win forms%"]'),
('Hibernate', '["%hibernate%", "%jpa%", "%entity framework%", "%ef core%"]'),
('SQL', '["%sql%", "%relational database%", "%rdbms%"]'),
('PostgreSQL', '["%postgresql%", "%postgres%"]'),
('MySQL', '["%mysql%"]'),
('Oracle DB', '["%oracle%database%", "%oracle%rdbms%", "%pl_sql%", "%oracle%", "oracle", "odi"]'),
('Oracle Apex', '["%apex%"]'),
('MongoDB', '["%mongodb%", "mongo db", "%cosmos db%", "%cosmosdb%"]'),
('Redis', '["%redis%", "%memcached%"]'),
('Elasticsearch', '["%elasticsearch%", "%elastic%", "%kibana%", "%logstash%", "%opensearch%", "%elk%", "%efk%", "%fluentd%", "%loki%"]'),
('Cassandra', '["%cassandra%", "%scylladb%", "%scylla db%"]'),
('MS SQL Server', '["%ms sql%", "%mssql%", "%microsoft sql%", "%sql server%"]'),
('SQLite', '["%sqlite%"]'),
('MariaDB', '["%mariadb%"]'),
('DynamoDB', '["%dynamodb%"]'),
('BigQuery', '["%bigquery%"]'),
('Snowflake', '["%snowflake%"]'),
('Redshift', '["%redshift%"]'),
('Databricks', '["%databricks%"]'),
('Neo4j', '["%neo4j%"]'),
('Db2', '["%db2%"]'),
('AWS', '["%aws%", "%amazon web%", "%amazon ec2%", "%amazon s3%", "%amazon eks%", "%amazon rds%", "%amazon sqs%", "%amazon bedrock%", "%aws lambda%", "%cloudformation%", "%cloudwatch%", "%vpc%", "%aws%glue%", "%kinesis%", "%athena%", "% s3 %", "%sns%"]'),
('Azure', '["%azure%", "%microsoft azure%", "%entra id%", "%azure ad%", "%bicep%", "%arm template%", "%key vault%", "%logic apps%", "%synapse%", "%intune%", "%adf%", "%microsoft fabric%", "%ms fabric%", "%dataverse%", "%microsoft purview%", "%adls%", "%azure%data lake%"]'),
('GCP', '["%gcp%", "%google cloud%", "%vertexai%", "%vertex ai%", "%dataform%", "%cloud run%", "%alloydb%", "%pub/sub%", "%pubsub%", "%compute engine%", "%dataflow%"]'),
('Cloud', '["%cloud%", "cloud", "cloud platform", "cloud computing", "cloud native", "%openstack%", "%open stack%", "%heroku%"]'),
('Terraform', '["%terraform%", "%terragrunt%", "%opentofu%", "%infrastructure as code%", "%iac%", "%iaac%"]'),
('Ansible', '["%ansible%", "%awx%"]'),
('Kubernetes', '["%kubernetes%", "%k8s%", "%aks%", "%eks%", "%gke%", "%istio%", "%kubeflow%", "%rancher%", "%kustomize%", "%ingress%"]'),
('Docker', '["%docker%", "%podman%", "%containerd%"]'),
('Helm', '["%helm%"]'),
('OpenShift', '["%openshift%"]'),
('Vagrant', '["%vagrant%"]'),
('Puppet', '["%puppet%"]'),
('ArgoCD', '["%argocd%", "%argo cd%"]'),
('VMware', '["%vmware%", "%vsphere%", "%kvm%", "%nutanix%", "%vdi%", "%vswitching%", "%vswitch%", "%hyper-v%", "%hyperv%", "%hyper v%", "%proxmox%", "%virtualization%", "%virtual machine%"]'),
('CI/CD', '["%ci/cd%", "%cicd%", "%continuous integration%", "%continuous delivery%", "%continuous deployment%", "%pipeline%", "ci", "cd", "cd tools", "%cd tools%", "%ci cd%", "%ci / cd%", "%artifactory%", "%jfrog%", "%harness%"]'),
('Jenkins', '["%jenkins%"]'),
('GitLab CI', '["%gitlab ci%", "%gitlab%"]'),
('GitHub/Git', '["%github actions%", "%github%", "git", "% git %", "%git/%", "%bitbucket%", "%svn%", "%gitops%", "%version control%", "%gitflow%"]'),
('Bamboo', '["%bamboo%"]'),
('TeamCity', '["%teamcity%", "%team city%"]'),
('Airflow', '["%airflow%", "%dagster%", "%control-m%", "%control m%"]'),
('DevOps', '["%devops%", "devops", "%devsecops%"]'),
('Grafana', '["%grafana%", "%thanos%"]'),
('Prometheus', '["%prometheus%"]'),
('Datadog', '["%datadog%"]'),
('Splunk', '["%splunk%"]'),
('Dynatrace', '["%dynatrace%"]'),
('Zabbix', '["%zabbix%"]'),
('New Relic', '["%new relic%"]'),
('Kafka', '["%kafka%", "%confluent%", "%schema registry%", "%solace%", "%tibco%", "%nats%"]'),
('Spark', '["%spark%", "%pyspark%", "%spark streaming%"]'),
('Hadoop', '["%hadoop%"]'),
('dbt', '["%dbt%", "%data build tool%", "dbt"]'),
('ETL', '["%etl%", "%etl/elt%", "etl", "elt", "%elt%", "%ssis%", "%talend%", "%datastage%", "%data stage%", "%ab initio%", "%informatica%", "%fivetran%", "%alteryx%"]'),
('Flink', '["%flink%"]'),
('Hive', '["%hive%"]'),
('Nifi', '["%nifi%"]'),
('Trino', '["%trino%"]'),
('Big Data', '["%big data%", "big data", "data engineering", "data science", "data modeling", "data modelling", "data lake", "data warehouse", "data management", "data pipelines", "data analysis", "data visualization", "data models", "data migration", "data integrity", "%hudi%", "%delta lake%", "%delta%lake%", "%lakehouse%", "%olap%", "%dwh%", "%data quality%", "%data mapping%", "%data catalog%", "%data mesh%", "%delta live tables%", "%iceberg%", "%apache iceberg%", "%parquet%", "%avro%", "%data mining%", "%data hub%", "%datahub%", "%data validation%", "%data governance%", "%data integration%", "%dataops%", "%collibra%", "%teradata%"]'),
('Machine Learning', '["%machine learning%", "% ml %", "%mlops%", "%scikit%", "%sklearn%", "%deep learning%", "%neural network%", "%ai/ml%", "%artificial intelligence%", "ml", "%cuda%", "%xgboost%", "%scipy%", "%matplotlib%", "%keras%", "%polars%", "%pydantic%"]'),
('LLM', '["%llm%", "%llms%", "%large language%", "%openai%", "%chatgpt%", "%gpt%", "%gemini%", "%hugging face%", "%huggingface%", "%prompt engineering%", "%llama%", "%llamaindex%", "%langgraph%", "%langfuse%", "%semantic kernel%"]'),
('Generative AI', '["%generative ai%", "%genai%", "%gen ai%", "%generativeai%", "%agentic ai%", "%ai agents%", "%ai agent%", "%model context protocol%", "ai", "%copilot%", "%copilot studio%", "%claude%", "%agentic%", "%ai tools%", "%n8n%", "%codex%", "%cursor%", "%vector database%", "%vector databases%"]'),
('RAG', '["rag", "%rag%"]'),
('TensorFlow', '["%tensorflow%"]'),
('PyTorch', '["%pytorch%"]'),
('MLflow', '["%mlflow%"]'),
('LangChain', '["%langchain%"]'),
('Computer Vision', '["%computer vision%", "%opencv%"]'),
('NLP', '["%nlp%", "%natural language%", "nlp"]'),
('Selenium', '["%selenium%"]'),
('Playwright', '["%playwright%"]'),
('Cypress', '["%cypress%"]'),
('JMeter', '["%jmeter%", "%jmetter%"]'),
('Postman', '["%postman%", "%bruno%"]'),
('JUnit', '["%junit%"]'),
('Pytest', '["%pytest%"]'),
('TestNG', '["%testng%"]'),
('ISTQB', '["%istqb%"]'),
('Robot Framework', '["%robot framework%"]'),
('Testing', '["%testing%", "testing", "qa", "tdd", "bdd", "uat", "%manual%test%", "%test%automat%", "automated testing", "api testing", "%mockito%", "%jest%", "%appium%", "%test case%", "%test cases%", "%e2e%", "%xunit%", "%nunit%", "%mstest%", "%spock%", "%k6%", "%gatling%", "%selenide%", "%jasmine%", "%mocha%", "%testcafe%", "%mockk%", "cucumber", "%gherkin%", "%testrail%", "%zephyr%", "%qtest%", "%tricentis%", "%tosca%", "%testcontainers%", "%karate%", "%karma%", "%loadrunner%", "%wiremock%", "%protractor%", "%sonarqube%", "%xray%", "%rspec%"]'),
('Jira', '["%jira%"]'),
('Confluence', '["%confluence%"]'),
('Atlassian', '["atlassian", "%atlassian%"]'),
('Scrum', '["%scrum%", "%scrum master%", "%product owner%", "%psm%", "%csm%"]'),
('Agile', '["%agile%", "%lean agile%", "%agile/lean%", "%agile/scrum%", "%waterfall%"]'),
('Kanban', '["%kanban%"]'),
('SAFe', '["%safe%", "%scaled agile%"]'),
('ITIL', '["%itil%", "%cmdb%"]'),
('Prince2', '["%prince2%"]'),
('Power BI', '["%power bi%", "%powerbi%", "%microsoft power bi%", "%power platform%", "%power automate%", "%power apps%", "%dax%", "%power query%"]'),
('Tableau', '["%tableau%"]'),
('Looker', '["%looker%"]'),
('QlikView', '["%qlik%"]'),
('Excel', '["%excel%", "%microsoft excel%", "%ms excel%"]'),
('BI', '["bi", "%business intelligence%", "%ssas%", "%ssrs%"]'),
('SAP', '["sap %", "% sap %", "% sap", "%s/4hana%", "%s4hana%", "%sap hana%", "sap", "sap fi", "sap sd", "sap mm", "sap ewm", "sap hcm", "sap analytics cloud", "sap erp", "sap integration", "%badi%", "%bapi%", "%idoc%", "%successfactors%", "%success factors%", "%fiori%"]'),
('ERP/CRM', '["%erp%", "erp", "%dynamics nav%", "%dynamics ax%", "%d365fo%", "%odoo%", "crm", "%crm%", "%dynamics crm%", "%hubspot%", "%zoho%", "%zendesk%", "%mendix%"]'),
('Security', '["%security%", "%cybersecurity%", "%cyber security%", "%owasp%", "%pentest%", "%penetration%", "%siem%", "%vulnerability%", "%threat%", "%cissp%", "%cism%", "%zero trust%", "%nist%", "%iso%", "%mfa%", "%dlp%", "%soc 2%", "%sox%", "%dast%", "%vault%", "%cisa%", "%pci%dss%", "%pci-dss%", "%hipaa%", "%hippa%", "%ssl%", "%tls%", "%tls/ssl%", "%saml%", "%waf%", "%nis2%", "%sast%", "%xss%", "%firewall%", "%fortinet%", "%nessus%", "%cyberark%", "%edr%", "%grc%", "%wireshark%", "%cryptography%", "%pki%", "%sonarqube%", "%trellix%", "%nmap%", "%incident response%", "%ips%", "%secret manag%"]'),
('OAuth', '["%oauth%"]'),
('LDAP/AD', '["%active directory%", "%ldap%", "%entra id%"]'),
('IAM', '["%iam%", "%identity%", "iam", "%abac%", "%pam%", "%okta%", "%sso%", "%single sign-on%", "%oidc%", "%openid%", "%rbac%", "%sailpoint%", "%iga%"]'),
('Keycloak', '["%keycloak%"]'),
('VPN', '["%vpn%", "vpn"]'),
('TCP/IP', '["%tcp/ip%", "%tcp%", "%ip routing%", "%ipv%", "%ipv4%", "%ipv6%", "%ospf%", "%sdwan%", "%sd-wan%", "%ipsec%"]'),
('DNS', '["%dns%", "dns"]'),
('Cisco', '["%cisco%", "%ccna%", "%ccnp%"]'),
('Linux', '["%linux%", "%ubuntu%", "%red hat%", "%rhel%", "%debian%", "%centos%", "%fedora%", "%suse%", "%kali%", "%yocto%", "%buildroot%", "%rocky linux%", "%macos%", "%mac os%", "%aix%"]'),
('Windows', '["%windows server%", "%windows%", "windows", "windows server"]'),
('Unix', '["%unix%", "unix"]'),
('Embedded', '["embedded", "%embedded%", "uart", "spi", "i2c", "pcie", "dma", "arm", "%uart%", "%spi%", "%i2c%", "%pcie%", "%iot%", "%internet of things%", "%cpu%", "%dpdk%", "%rtos%", "%freertos%", "%scada%", "%plc%"]'),
('MATLAB', '["matlab", "%matlab%", "%simulink%"]'),
('Android', '["%android%", "android", "android studio", "%jetpack%compose%", "%jetpack compose%", "%kmp%", "%firebase%"]'),
('iOS', '["%ios%", "ios", "%cocoapods%"]'),
('Flutter', '["%flutter%", "flutter"]'),
('REST API', '["%rest api%", "%restful%", "%rest assured%", "%web%service%", "%api rest%", "%restapi%", "%web%api%", "%api integration%", "rest", "api", "soap", "soapui", "%http%", "%gateway%", "%odata%", "%odata v4%", "%asyncapi%", "%mqtt%", "%jwt%"]'),
('GraphQL', '["%graphql%"]'),
('gRPC', '["%grpc%"]'),
('Swagger', '["%swagger%", "%openapi%"]'),
('JSON/XML/YAML', '["json", "xml", "yaml", "%json%", "%xml%", "%yaml%"]'),
('Microservices', '["%microservice%", "%micro service%", "%service mesh%", "%event driven%", "%event-driven%", "%distributed system%", "%soa%", "%service oriented%", "%esb%", "%websocket%", "%websockets%", "%message queue%", "%service bus%", "%kong%"]'),
('UML', '["%uml%", "uml", "%archimate%", "%archi mate%", "%visio%", "%ms visio%", "%draw.io%"]'),
('BPMN', '["%bpmn%", "%camunda%", "%ibm bpm%", "% bpm %"]'),
('Enterprise Architect', '["enterprise architect", "%enterprise architect%"]'),
('TOGAF', '["togaf", "%togaf%"]'),
('Figma', '["%figma%", "%figjam%"]'),
('Salesforce', '["%salesforce%"]'),
('ServiceNow', '["%servicenow%", "%service now%"]'),
('SharePoint', '["%sharepoint%"]'),
('Dynamics 365', '["%dynamics 365%", "%dynamics365%", "microsoft dynamics", "%d365%"]'),
('Workday', '["%workday%"]'),
('MS Office', '["ms office", "microsoft office", "microsoft 365", "powerpoint", "%ms office%", "%microsoft office%", "%microsoft 365%", "%m365%", "%ms365%", "%ms 365%", "%o365%", "%office 365%", "%office365%", "%ms teams%", "%exchange online%", "%ms project%", "%microsoft project%", "%google workspace%"]'),
('RabbitMQ', '["%rabbitmq%", "%rabbit mq%", "rabbitmq"]'),
('Message Brokers', '["%ibm mq%", "%activemq%", "%mulesoft%"]'),
('Maven', '["%maven%", "maven"]'),
('Gradle', '["%gradle%", "gradle"]'),
('Build Tools', '["npm", "cargo", "conan", "nexus", "%nexus%", "%cmake%", "%webpack%", "%vite%", "%bazel%", "%yarn%"]'),
('Communication skills', '["communication skills", "%communication%", "%documentation%", "%negot%"]'),
('Analytical skills', '["analytical skills", "%analytical%", "%analytics%"]'),
('Stakeholder management', '["stakeholder management", "%stakeholder%"]'),
('Project Management', '["project management", "%management%", "%sdlc%", "%pmbok%", "%itsm%", "%itom%", "%ms project%", "%microsoft project%", "%dora%", "%asana%", "%redmine%"]'),
('UX/UI', '["ux", "ui", "ux_ui", "%ux%", "%ui%", "%wcag%", "%design system%", "%design systems%", "%tokens studio%", "%adobe xd%", "%balsamiq%", "%sketch%", "%accessibility%", "%a11y%", "%miro%", "%wireframe%", "%prototyp%", "%storybook%", "%material design%", "%draw.io%"]'),
('Networking', '["networking", "%lan%", "%lan/wan%", "%bgp%", "%dhcp%", "%vlan%", "%mpls%", "%wan%", "%switches%", "%vswitching%", "%dpdk%", "%spdk%", "%cdn%", "%load balanc%", "%ethernet%", "%fortinet%", "%palo alto%", "%firewall%", "%aruba%", "% 5g %", "%lte%"]'),
('OOP', '["oop", "% oop %", "%clean%code%", "%solid%", "%design pattern%", "mvvm", "mvc", "ddd", "%domain driven%", "%domain-driven%", "%object-oriented%", "%cqrs%", "%event sourcing%", "%dry%", "%functional programming%"]'),
('Backend', '["%backend%"]'),
('Pandas', '["%pandas%"]'),
('Numpy', '["%numpy%"]'),
('Nest.js', '["%nest%js%", "%nestjs%"]'),
('SaaS', '["saas", "%saas%", "%software as a service%"]'),
('COBOL', '["cobol", "%cobol%", "%mainframe%", "%jcl%"]'),
('SAS', '["sas", "%sas%"]'),
('Software Design', '["clean architecture", "%clean%architecture%", "%solid%principles%", "%design%pattern%", "%system design%", "%solution design%", "%hexagonal%", "%cqrs%", "%event sourcing%"]'),
('Web Servers', '["nginx", "%nginx%", "tomcat", "%tomcat%", "weblogic", "%weblogic%", "%jboss%", "%wildfly%", "%iis%", "%apache%", "%websphere%", "%ibm websphere%"]'),
('IDE Tools', '["visual studio", "%visual studio%", "intellij", "%intellij%", "xcode", "%xcode%", "vscode", "%vs code%", "%eclipse%", "%cursor%"]'),
('Business Analysis', '["business analysis", "%business anal%", "business analyst", "%business analyst%", "analiza biznesowa", "analiza systemowa", "%system anal%", "%use case%", "%use cases%", "%user stor%", "%archimate%"]'),
('CMS', '["cms", "%cms%", "magento", "%magento%", "wordpress", "%wordpress%", "%contentful%", "%drupal%", "%shopify%"]'),
('IoT', '["iot", "%iot%", "%internet of things%"]'),
('SSIS/SSAS', '["ssis", "%ssis%", "ssas", "%ssas%"]'),
('PMP', '["pmp", "%pmp%", "sdlc", "%sdlc%"]'),
('RPA', '["uipath", "%uipath%", "%automation anywhere%", "%blue prism%"]'),
('Observability', '["observability", "%observability%", "%opentelemetry%", "%otel%", "%tracing%", "%jaeger%", "%zipkin%"]'),
('SRE', '["sre", "%site reliability%", "%site reliability engineering%", "%slo%", "%sli%", "%error budget%", "%incident management%", "%postmortem%", "%reliability engineering%"]'),
('GDPR', '["gdpr", "%gdpr%", "%rodo%", "%general data protection%", "%data protection regulation%"]')

ON CONFLICT (tech_name) DO UPDATE SET like_patterns = EXCLUDED.like_patterns;







--- -----------------------------------------------------------------------------
-- Tabela: gold.D_BENEFIT
-- OPIS: Słownik benefitów z wzorcami LIKE do dopasowania z silver.offer_benefits
--- -----------------------------------------------------------------------------


INSERT INTO gold.D_BENEFIT (benefit_name, like_patterns) VALUES

('Bonus za wyniki',             '["bonus%", "%bonus%", "%premi%", "%award%", "%jubileusz%", "%jubilel%", "%roczn%", "%kwartaln%", "%trzynast%", "%13%pensj%", "%recognition%", "%sign-up%", "%powitaln%", "%welcome pack%", "%konkurs%", "%nagrody za staż%", "%świąt%", "%christmas%", "%bony na święta%", "%bony podarunkowe%", "%karty przedpłacone%", "%pre-paid%"]'),

('Program poleceń',             '["program poleceń%", "%program poleceń%", "%polecen%", "%referral%", "%rekomendacj%", "%refer a friend%", "%program rekomendacji%"]'),

('Opcje na akcje',              '["stock option%", "%esop%", "%essp%", "%equity%", "%rsu%", "%restricted stock%", "%share purchase%", "%stock program%"]'),

('Ulga podatkowa (50% KUP)',    '["creative tax%", "%authorship tax%", "%ulga podatkow%", "%tax-deductible%", "%tax relief%", "%koszty uzyskania przychodu%", "%twórc%"]'),

('Pożyczki pracownicze',        '["%pożyczk%", "%loan%", "%kasa zapomogowo%", "%zapomogowo%", "%preferencyjne pożyczki%", "%preferential loan%"]'),

('Prywatna opieka medyczna',    '["%medicover%", "%luxmed%", "%enel%med%", "%opieka medyczn%", "%prywatna opieka%", "%private medical%", "%private health%", "%medical care%", "%medical insurance%", "%medical package%", "%health insurance%", "%health benefit%", "%lekarz%", "%physiotherap%", "%inter polska%", "%pzu%", "%opieka zdrowotna%", "%pakiet zdrowotny%", "%profilaktyczn%", "%badania profilaktyczne%", "%placówka medyczn%", "%dofinansowan%medyczn%", "%dofinansowan%opieki medycznej%"]'),

('Wsparcie psychologiczne',     '["%psycholog%", "%mental health%", "%mindgram%", "%therapist%", "%psychiatr%", "%eap%", "%employee assistance%", "%wsparcie psycholog%", "%platforma wsparcia%", "%psychological%", "%psychotherap%", "%calm app%", "%program wsparcia%", "%terapeutyczn%", "%terapeutą%", "%helpline%", "%dobrostan%", "%bezpłatny czat%rozmowa z%", "%darmowa pomoc psycholog%"]'),

('Ubezpieczenie na życie',      '["%ubezpieczenie na życie%", "%ubezpieczenia na życie%", "%ubezpieczenia grupowe%", "%ubezpieczenie grupowe%", "%life insurance%", "%group life%", "%group insurance%", "%income protection%", "%lloyd%", "%uniqua%", "%unum%", "%ubezpieczenie szpitaln%", "%ubezpieczenie leków%", "%lekowe%", "%ubezpieczenie dostępn%", "%rozbudowane ubezpieczenie%", "%oferta grupowego ubezpieczenia%", "%stomatolog%", "%dental%", "%możliwość dołączenia do ubezpieczenia%", "%insurance%"]'),

('Ubezpieczenie podróżne',      '["%travel insur%", "%life & travel%", "%travel safety%", "%emergency travel%", "%travel assistance%", "%travel insurance%", "%international travel%"]'),

('Dofinansowanie okularów',     '["%okular%", "%soczewk%", "%glasses%", "%contact lens%", "%spectacles%", "%refundacja okularów%", "%co-financing of glasses%"]'),

('Karta sportowa',              '["%multisport%", "%karta sport%", "%pakiet sport%", "%sport subscription%", "%fitness%", "%gym card%", "%sport card%", "%multilife%", "%sekcje sportowe%", "%zajęcia sport%", "%treningi%", "%biegow%", "%medicover sport%", "%firmowe inicjatywy sportowe%", "%firmowa drużyna sportowa%", "%company sports%", "%corporate sports%", "%aktywna przerwa%", "%firmowe treningi%", "%sharing the costs of sports%", "%dofinansowan%kart%sport%", "%dofinansowanie zajęć sportowych%"]'),

('Siłownia w biurze',           '["%siłowni%", "%in-office gym%", "%corporate gym%"]'),

('Program wellness',            '["%wellness%", "%wellbeing%", "%well-being%", "%masaż%", "%massage%", "%yoga%", "%joga%", "%fizjoterapeu%", "%usługi fizjoterapeuty%"]'),

('Dofinansowanie lunchów',      '["%lunch%", "%lunchow%", "%lunchpass%", "%posiłk%", "%stołówk%", "%catering%", "%meal%", "%obiady%", "%obiadów%", "%śniadani%", "%smart lunch%", "%salad bar%", "%bony żywienio%", "%vending%", "%pizza%", "%bistro%", "%kantyn%", "%canteen%", "%dopłata do%", "%dofinansowane posiłki%", "%karta żywieniowa%", "%bony towarowe%", "%napojów%przekąsek%"]'),

('Owoce i przekąski',           '["%owoc%", "%fruit%", "%przekąsk%", "%snack%", "%warzywa%", "%świeże owoce%"]'),

('Kawa i napoje',               '["%kawa%", "%coffee%", "%herbat%", "%napoje%", "%drinks%", "%kawiarni%", "%open bar%"]'),

('Budżet szkoleniowy',          '["%szkoleni%", "%training%", "%learning%", "%development%", "%hack%week%", "%hackday%", "%library%", "%bibliotek%", "%rozwój%", "%studia na uczelni%", "%dofinansowanie do studiów%", "%esg academy%", "%ścieżka rozwoju%", "%akademia%", "%dofinansowan%szkoleń%", "%access to courses%", "%dostęp do kursów%", "%oferta szkoleń%", "%katalog szkoleń%", "%programy rozwojowe%", "%działania rozwojowe%", "%harmonogram szkoleń%", "%możliwość rozwoju%", "%in-house courses%", "%indywidualny program szkoleń%", "%trener wewnętrzny%"]'),

('Dofinansowanie konferencji',  '["%konferencj%", "%conference%"]'),

('Dofinansowanie certyfikatów', '["%certyfikat%", "%certification%", "%certif%", "%uprawni%", "%permits%", "%licenses%"]'),

('Platforma e-learningowa',     '["%udemy%", "%pluralsight%", "%linkedin learning%", "%degreed%", "%mindtools%", "%e-learning%", "%elearning%", "%platforma edukacyjn%", "%github copilot%", "%llm credits%", "%dialoteka%", "%etutor%", "%o''reilly%", "%seduo%", "%gofluent%", "%audiobooków%", "%e-booków%", "%aplikacja treści audio%", "%platforma e-learningowa%", "%wewnętrzna platforma szkoleniowa%", "%platforma ze szkoleniami%", "%online training platform%"]'),

('Kursy językowe',              '["%język%", "%language%", "%angielski%", "%english%", "%german%", "%językow%", "%language course%", "%speaking club%", "%language cafe%", "%norwegian%", "%italian%", "%french%", "%nauka języka%", "%lekcje języka%"]'),

('Mentoring i coaching',        '["%mentor%", "%coaching%", "%buddy%", "%knowledge sharing%", "%sharing wiedzy%", "%gildi%", "%meetup%", "%webinar%", "%tech community%", "%koła zainteresow%", "%spotkania gildii%", "%hackathon%"]'),

('Praca zdalna',                '["%remote%", "%praca zdalna%", "%home office%", "%zdaln%", "%work from home%", "%możliwość pracy zdalnej%", "%freedom to choose your working model%"]'),

('Elastyczne godziny',          '["%elastyczn%", "%flexible hour%", "%flexible time%", "%flexible schedule%", "%flexible form%", "%krótszy dzień%", "%krótsze piątki%", "%jeden krótszy%", "%flexi time%", "%one shorter%", "%godziny pracy%", "%flexi%"]'),

('Praca hybrydowa',             '["%hybrid%", "%hybrydow%", "%praca hybrydow%"]'),

('Budżet na home office',       '["%home office%setup%", "%home office%budget%", "%home office%reimb%", "%dofinansowan%home office%", "%workstation reimb%", "%home work allowance%", "%remote work subsidy%", "%doposażenia biura domowego%"]'),

('Workation',                   '["%workation%", "%work from abroad%"]'),

('Platforma kafeteryjna',       '["%mybenefit%", "%kafeteria%", "%cafeteria%", "%kafeteryjn%", "%motivizer%", "%worksmile%", "%medicover benefits%", "%benefit platform%", "%platforma benefitow%", "%multikafeteria%", "%nais%", "%loyaltybox%", "%shopping coupon%", "%zniżk%", "%rabat%", "%discount%", "%biletów do kina%", "%tickets to the movies%", "%streaming%"]'),

('Urlop rodzicielski',          '["%parental leave%", "%maternity%", "%urlop macierzyńsk%", "%urlop rodzicielski%", "%urlop wychowawcz%"]'),

('Świadczenia dla dzieci',      '["%wyprawka%", "%dziecko%", "%dzieci%", "%child%", "%kolonie%", "%żłobek%", "%przedszkole%", "%nanny%", "%baby%", "%layette%", "%foteliki%", "%kindergarten%", "%nursery%", "%junior%programme%", "%prezenty z okazji narodzin%", "%program%mam%", "%sharing the costs of holidays for kids%"]'),

('Dofinansowanie wakacji',      '["%wczasy pod gruszą%", "%holiday allowance%", "%dofinansowan%wakacj%", "%dofinansowan%wypoczynku%", "%holiday fund%", "%tourist services%", "%usług turystyczn%", "%premia wakacyjna%", "%wakacje decerto%"]'),

('Dzień wolny na urodziny',     '["%birthday%day%", "%birthday%leave%", "%birthday%off%", "%birthday celebration%", "%urodzin%", "%urlop urodzinow%", "%świętowanie urodzin%", "%imienin%", "%upominek%urodzin%"]'),

('Dodatkowe dni wolne',         '["%additional%day%off%", "%additional%holiday%", "%extra leave%", "%extra day%", "%paid time off%", "%unlimited%vacation%", "%unlimited pto%", "%dodatkow%dni%woln%", "%dodatkow%urlop%", "%sick day%", "%sick leave%", "%paid leave%", "%sabbatical%", "%dni urlopu%", "%płatne dni wolne%", "%1 dodatkowy%", "%dodatkowy dzień wolny%", "%wolny od świadczenia%", "%chorobowego%", "%stand-by%", "%dni wolnego%", "%dodatkowy urlop%", "%paid holidays%"]'),

('Fundusz socjalny (ZFŚS)',     '["%zfśs%", "%fundusz socjaln%", "%social fund%", "%świadczenia socjaln%", "%zakładowy fundusz%", "%fundusz świadczeń%", "%extra social benefit%"]'),

('Parking',                     '["%parking%"]'),

('Udogodnienia dla rowerzystów','["%rower%", "%bicycle%", "%cyclist%", "%bike%", "%prysznic%", "%garaż rowerowy%", "%wypożyczalnia rowerów%", "%klub bikeair%"]'),

('Dofinansowanie dojazdów',     '["%dojazd%", "%commut%", "%zwrot kosztów dojazd%", "%karta miejsk%", "%transport pracowniczy%", "%transport autobusem%", "%kolejow%", "%koleją%", "%ulgowe%transport%", "%taryfa pracown%", "%sharing the commuting%"]'),

('Samochód służbowy',           '["%samochód służbow%", "%company car%", "%car allowance%", "%służbowy samochód%"]'),

('Pakiet relokacyjny',          '["%relokacyjn%", "%relocation%"]'),

('Sprzęt komputerowy',          '["%laptop%", "%macbook%", "%sprzęt%", "%equipment%", "%komputer%", "%narzędzia%", "%workstation%", "%monitor%", "%biurko%", "%jetbrains%", "%intellij%", "%apple device%", "%ssd%", "%ergonomiczn%stanowisko%", "%solidne narzędzia%", "%narzędzia niezbędne%", "%available for private use%"]'),

('Telefon służbowy',            '["%telefon%", "%phone%", "%mobile phone%", "%służbowy telefon%", "%komórkow%"]'),

('Eventy integracyjne',         '["%integracj%", "%team event%", "%company event%", "%team building%", "%piknik%", "%offsite%", "%away day%", "%imprezy firmow%", "%wyjazd integracyjn%", "%zagraniczne wyjazdy%", "%family event%", "%family picnic%", "%eventy%", "%grille i imprezy%", "%grill%", "%nurkowanie%", "%turniej%", "%wydarzenia rodzinne%", "%świętowanie ważnych%", "%integration events%", "%integration budget%", "%firmowe wydarzenia%", "%integracy%"]'),

('Rozrywka w biurze',           '["%piłkarzyk%", "%foosball%", "%table tennis%", "%playstation%", "%nintendo%", "%board game%", "%pool table%", "%darts%", "%ps5%", "%gry wideo%", "%video game%", "%strefa relaksu%", "%strefa rozrywki%", "%leisure zone%", "%game room%", "%planszoteka%", "%pinball%"]'),

('Wolontariat i CSR',           '["%wolontariat%", "%charity%", "%csr%", "%dobroczynne%", "%inicjatywy społeczn%", "%projekty wolontariackie%", "%wolontaryjn%", "%volunteer day%", "%day for volunteer%", "%charytatywnych%", "%inicjatywy dobroczynne%", "%wsparcie w inicjatywach%"]'),

('Plan emerytalny (PPK/PPE)',   '["%ppk%", "%ppe%", "%pension%", "%emerytaln%", "%retirement%", "%saving%investment%", "%fundusz oszczędnościow%", "%plany kapitałowe%", "%program emerytalny%", "%pracowniczy program emerytalny%"]'),

('Międzynarodowe projekty',     '["%międzynarodow%projekt%", "%international project%", "%international team%", "%international environment%", "%global%project%", "%international client%", "%praca w międzynarodow%", "%możliwość pracy w międzynarodow%"]'),

('Brak dress code',             '["%dress code%", "%dress-code%", "%bez wymaganego dress%", "%brak dress%", "%no dress%", "%casual dress%", "%business casual%"]'),

('Małe zespoły',                '["%małe zespoły%", "%small team%", "%mały zespół%", "%small team%", "%flat structure%", "%płaska struktura%", "%holacracy%", "%turkus%", "%brak korporacyjn%", "%no corporate%", "%non-corporate%", "%startup atmosphere%", "%atmosfera startupu%", "%skandynawska kultura%"]')

ON CONFLICT (benefit_name) DO UPDATE SET like_patterns = EXCLUDED.like_patterns;