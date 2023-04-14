/*<TOAD_FILE_CHUNK>*/

CREATE OR REPLACE PACKAGE safe_update
IS
    TYPE pipe_records IS RECORD
    (
        def_id          NUMBER(10)
       ,sname           VARCHAR2(254)
       ,sdescription    VARCHAR2(254)
       ,parent_id       NUMBER(10)
    );

    TYPE defect_type IS TABLE OF pipe_records;

    PROCEDURE UPDATE_RECORD(p_id             IN     defect_locations.nid%TYPE
                           ,p_sdescription   IN     defect_locations.sdescription%TYPE
                           ,e_message           OUT VARCHAR2);

    FUNCTION get_records
        RETURN defect_type
        PIPELINED;

    PROCEDURE INSERT_RECORD(p_sname          IN OUT defect_locations.sname%TYPE
                           ,p_sdescription          defect_locations.sdescription%TYPE
                           ,e_message           OUT VARCHAR2);

    PROCEDURE check_strings(sp_string   IN OUT VARCHAR2
                           ,serror         OUT VARCHAR2
                           ,nerror         OUT NUMBER);

    PROCEDURE UPDATE_RECORD(js_data VARCHAR2);
END safe_update;
/

/*<TOAD_FILE_CHUNK>*/

CREATE OR REPLACE PACKAGE BODY safe_update
IS
    --UPDATE RECORD IN DEFECT_LOCATIONS TABLE
    PROCEDURE UPDATE_RECORD(p_id             IN     defect_locations.nid%TYPE
                           ,p_sdescription   IN     defect_locations.sdescription%TYPE
                           ,e_message           OUT VARCHAR2)
    IS
        null_value     EXCEPTION;
        wrong_format   EXCEPTION;
        check_result   BOOLEAN;
    BEGIN
        IF p_sdescription IS NULL THEN
            RAISE null_value;
        END IF;

        --    check_result := check_strings(p_sdescription);

        IF NOT check_result THEN
            RAISE wrong_format;
        END IF;

        UPDATE defect_locations
        SET    sdescription = p_sdescription
        WHERE  nid = p_id;
    EXCEPTION
        WHEN null_value THEN
            e_message := 'Description not found';
        WHEN wrong_format THEN
            e_message := 'Description not capital';
    END UPDATE_RECORD;


    -- GET ALL RECORDS FROM A VIEW BASED ON DEFECT_LOCATIONS TABLE
    FUNCTION get_records
        RETURN defect_type
        PIPELINED
    IS
        l_row   pipe_records;

        CURSOR cur_my_view IS SELECT nid, sname, sdescription, nparentid FROM defects;
    BEGIN
        FOR r IN cur_my_view
        LOOP
            l_row :=
                pipe_records(r.nid
                            ,r.sname
                            ,r.sdescription
                            ,NVL(r.nparentid, 0));
            PIPE ROW (l_row);
        END LOOP;

        RETURN;
    END get_records;


    -- INSERT RECORDS INTO DEFECT_LOCATIONS
    PROCEDURE INSERT_RECORD(p_sname          IN OUT defect_locations.sname%TYPE
                           ,p_sdescription          defect_locations.sdescription%TYPE
                           ,e_message           OUT VARCHAR2)
    IS
        ip_message        VARCHAR2(200);
        ip_code           NUMBER(3);
        null_value_name   EXCEPTION;
        null_value_desc   EXCEPTION;
        wrong_format      EXCEPTION;
    BEGIN
        IF p_sname IS NULL THEN
            RAISE null_value_name;
        ELSIF p_sdescription IS NULL THEN
            RAISE null_value_desc;
        END IF;

        check_strings(p_sname
                     ,ip_message
                     ,ip_code);

        IF ip_code != 0 THEN
            RAISE wrong_format;
        END IF;

        INSERT INTO defect_locations(sname
                                    ,sdescription
                                    ,nparentid)
        VALUES      (p_sname
                    ,p_sdescription
                    ,0);
    EXCEPTION
        WHEN null_value_name THEN
            e_message := 'Name not found';
        WHEN null_value_desc THEN
            e_message := 'Description not found';
        WHEN wrong_format THEN
            e_message := ip_message;
    END INSERT_RECORD;


    -- FUNCTION TO VALIDATE AND FORMAT STRINGS [Is first letter capital, remove spaces, check length]
    PROCEDURE check_strings(sp_string   IN OUT VARCHAR2
                           ,serror         OUT VARCHAR2
                           ,nerror         OUT NUMBER)
    IS
    BEGIN
        sp_string := LTRIM(sp_string);
        sp_string := RTRIM(sp_string);
        serror := NULL;
        nerror := NULL;

        IF TRANSLATE(sp_string
                    ,'0123456789'
                    ,'##########') != sp_string THEN
            serror := 'Contains digits';
            nerror := 1;
        ELSIF SUBSTR(sp_string
                    ,1
                    ,1) != SUBSTR(INITCAP(sp_string)
                                 ,1
                                 ,1) THEN
            serror := 'First letter not capital';
            nerror := 2;
        ELSIF LENGTH(sp_string) >= 31 THEN
            serror := 'Text too long';
            nerror := 3;
        END IF;
    END check_strings;

    PROCEDURE UPDATE_RECORD(js_data VARCHAR2)
    IS
        l_json_object       json_object_t := json_object_t.parse(js_data);
        nid_json            json_element_t := l_json_object.get('nid');
        sdescription_json   json_element_t := l_json_object.get('sdescription');

        sdesc_update        VARCHAR2(200);
        nid_update          NUMBER(10);
    BEGIN
        sdesc_update := TO_CHAR(sdescription_json.to_string());
        sdesc_update :=
            LTRIM(sdesc_update
                 ,'"');
        sdesc_update :=
            RTRIM(sdesc_update
                 ,'"');
        nid_update := nid_json.TO_NUMBER();

        UPDATE defect_locations
        SET    sdescription = sdesc_update
        WHERE  nid = nid_update;
    END UPDATE_RECORD;
END safe_update;
/

