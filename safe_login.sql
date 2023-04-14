/*<TOAD_FILE_CHUNK>*/
CREATE OR REPLACE PACKAGE safe_login
AS
    PROCEDURE hash_values(sp_username   IN VARCHAR2
                         ,sp_password   IN VARCHAR2);

    PROCEDURE login(sp_username   IN     VARCHAR2
                   ,sp_password   IN     VARCHAR2
                   ,serror           OUT VARCHAR2
                   ,nerror           OUT NUMBER);
END safe_login;
/

/*<TOAD_FILE_CHUNK>*/

CREATE OR REPLACE PACKAGE BODY safe_login
AS
    PROCEDURE hash_values(sp_username   IN VARCHAR2
                         ,sp_password   IN VARCHAR2)
    IS
        sl_salt       VARCHAR2(100) := dbms_crypto.randombytes(32);
        sl_password   VARCHAR2(100);
        sl_hash       VARCHAR2(100);
    BEGIN
        sl_password := sp_password || sl_salt;
        sl_hash :=
            dbms_crypto.hash(utl_i18n.string_to_raw(sl_password
                                                   ,'AL32UTF8')
                            ,dbms_crypto.hash_sh256);

        INSERT INTO auth_table(nid
                              ,susername
                              ,spassword
                              ,s_salt)
        VALUES      (app_users_seq.NEXTVAL
                    ,sp_username
                    ,sl_hash
                    ,sl_salt);

        COMMIT;
    END hash_values;

    PROCEDURE login(sp_username   IN     VARCHAR2
                   ,sp_password   IN     VARCHAR2
                   ,serror           OUT VARCHAR2
                   ,nerror           OUT NUMBER)
    IS
        sl_salt        VARCHAR2(100);
        sl_password    VARCHAR2(100);
        sl_hash        VARCHAR2(100);
        sl_message     VARCHAR2(50);
        missing_data   EXCEPTION;
    BEGIN
        IF sp_username IS NULL THEN
            sl_message := 'Username missing';
            RAISE missing_data;
        ELSIF sp_password IS NULL THEN
            sl_message := 'Password missing';
            RAISE missing_data;
        END IF;

        SELECT s_salt
              ,spassword
        INTO   sl_salt
              ,sl_password
        FROM   auth_table
        WHERE  susername = sp_username;
        
        sl_hash :=
            dbms_crypto.hash(utl_i18n.string_to_raw(sp_password || sl_salt
                                                   ,'AL32UTF8')
                            ,dbms_crypto.hash_sh256);

        IF sl_password = sl_hash THEN
            serror := 'success';
            nerror := 0;
        ELSE
            nerror := 1;
            serror := 'Login failed';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            serror := 'User not found';
        WHEN missing_data THEN
            serror := sl_message;
    END login;
END safe_login;
/

