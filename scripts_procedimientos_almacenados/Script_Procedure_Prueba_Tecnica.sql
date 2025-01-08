CREATE OR ALTER PROCEDURE [dbo].[sp_GetUserPermissions]
    @EntityCatalogId INT,
    @UserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    -- Tabla temporal para almacenar los resultados
    CREATE TABLE #EffectivePermissions (
        RecordId BIGINT NULL,
        PermissionName NVARCHAR(255),
        RoleName NVARCHAR(255) NULL,
        CompanyName NVARCHAR(255),
        EffectiveCreate BIT,
        EffectiveRead BIT,
        EffectiveUpdate BIT,
        EffectiveDelete BIT,
        EffectiveImport BIT,
        EffectiveExport BIT,
        SourceType VARCHAR(20)
    );

    -- Obtener las compañías del usuario
    DECLARE @UserCompanies TABLE (
        UserCompanyId BIGINT,
        CompanyId BIGINT,
        CompanyName NVARCHAR(255)
    );
    
    INSERT INTO @UserCompanies
    SELECT 
        uc.id_useco,
        uc.company_id,
        c.compa_name
    FROM UserCompany uc
    INNER JOIN Company c ON uc.company_id = c.id_compa
    WHERE uc.user_id = @UserId 
    AND uc.useco_active = 1;

    -- Obtener los roles del usuario
    DECLARE @UserRoles TABLE (
        RoleId BIGINT,
        RoleName NVARCHAR(255),
        CompanyId BIGINT
    );
    
    INSERT INTO @UserRoles
    SELECT DISTINCT 
        r.id_role,
        r.role_name,
        r.company_id
    FROM Role r
    INNER JOIN UserCompany uc ON r.company_id = uc.company_id
    WHERE uc.user_id = @UserId 
    AND r.role_active = 1 
    AND uc.useco_active = 1;

    -- 1. Procesar permisos a nivel de rol (base)
    INSERT INTO #EffectivePermissions
    SELECT 
        NULL AS RecordId,
        p.name AS PermissionName,
        ur.RoleName,
        uc.CompanyName,
        CASE WHEN pr.perol_include = 1 THEN p.can_create ELSE 0 END,
        CASE WHEN pr.perol_include = 1 THEN p.can_read ELSE 0 END,
        CASE WHEN pr.perol_include = 1 THEN p.can_update ELSE 0 END,
        CASE WHEN pr.perol_include = 1 THEN p.can_delete ELSE 0 END,
        CASE WHEN pr.perol_include = 1 THEN p.can_import ELSE 0 END,
        CASE WHEN pr.perol_include = 1 THEN p.can_export ELSE 0 END,
        'Role' AS SourceType
    FROM PermiRole pr
    INNER JOIN @UserRoles ur ON pr.role_id = ur.RoleId
    INNER JOIN Permission p ON pr.permission_id = p.id_permi
    INNER JOIN @UserCompanies uc ON ur.CompanyId = uc.CompanyId
    WHERE pr.entitycatalog_id = @EntityCatalogId;

    -- 2. Sobrescribir con permisos a nivel de rol-registro si existen
    INSERT INTO #EffectivePermissions
    SELECT 
        prr.perrc_record AS RecordId,
        p.name AS PermissionName,
        ur.RoleName,
        uc.CompanyName,
        CASE WHEN prr.perrc_include = 1 THEN p.can_create ELSE 0 END,
        CASE WHEN prr.perrc_include = 1 THEN p.can_read ELSE 0 END,
        CASE WHEN prr.perrc_include = 1 THEN p.can_update ELSE 0 END,
        CASE WHEN prr.perrc_include = 1 THEN p.can_delete ELSE 0 END,
        CASE WHEN prr.perrc_include = 1 THEN p.can_import ELSE 0 END,
        CASE WHEN prr.perrc_include = 1 THEN p.can_export ELSE 0 END,
        'RoleRecord' AS SourceType
    FROM PermiRoleRecord prr
    INNER JOIN @UserRoles ur ON prr.role_id = ur.RoleId
    INNER JOIN Permission p ON prr.permission_id = p.id_permi
    INNER JOIN @UserCompanies uc ON ur.CompanyId = uc.CompanyId
    WHERE prr.entitycatalog_id = @EntityCatalogId;

    -- 3. Sobrescribir con permisos a nivel de usuario si existen
    INSERT INTO #EffectivePermissions
    SELECT 
        NULL AS RecordId,
        p.name AS PermissionName,
        NULL AS RoleName,
        uc.CompanyName,
        CASE WHEN pu.peusr_include = 1 THEN p.can_create ELSE 0 END,
        CASE WHEN pu.peusr_include = 1 THEN p.can_read ELSE 0 END,
        CASE WHEN pu.peusr_include = 1 THEN p.can_update ELSE 0 END,
        CASE WHEN pu.peusr_include = 1 THEN p.can_delete ELSE 0 END,
        CASE WHEN pu.peusr_include = 1 THEN p.can_import ELSE 0 END,
        CASE WHEN pu.peusr_include = 1 THEN p.can_export ELSE 0 END,
        'User' AS SourceType
    FROM PermiUser pu
    INNER JOIN @UserCompanies uc ON pu.usercompany_id = uc.UserCompanyId
    INNER JOIN Permission p ON pu.permission_id = p.id_permi
    WHERE pu.entitycatalog_id = @EntityCatalogId;

    -- 4. Finalmente, sobrescribir con permisos a nivel de usuario-registro si existen
    INSERT INTO #EffectivePermissions
    SELECT 
        pur.peusr_record AS RecordId,
        p.name AS PermissionName,
        NULL AS RoleName,
        uc.CompanyName,
        CASE WHEN pur.peusr_include = 1 THEN p.can_create ELSE 0 END,
        CASE WHEN pur.peusr_include = 1 THEN p.can_read ELSE 0 END,
        CASE WHEN pur.peusr_include = 1 THEN p.can_update ELSE 0 END,
        CASE WHEN pur.peusr_include = 1 THEN p.can_delete ELSE 0 END,
        CASE WHEN pur.peusr_include = 1 THEN p.can_import ELSE 0 END,
        CASE WHEN pur.peusr_include = 1 THEN p.can_export ELSE 0 END,
        'UserRecord' AS SourceType
    FROM PermiUserRecord pur
    INNER JOIN @UserCompanies uc ON pur.usercompany_id = uc.UserCompanyId
    INNER JOIN Permission p ON pur.permission_id = p.id_permi
    WHERE pur.entitycatalog_id = @EntityCatalogId;

    -- Retornar los permisos efectivos consolidados
    SELECT 
		RecordId,
		PermissionName,
		RoleName,
		CompanyName,
		EffectiveCreate,
		EffectiveRead,
		EffectiveUpdate,
		EffectiveDelete,
		EffectiveImport,
		EffectiveExport,
		SourceType
	FROM (
		SELECT 
			*,
			ROW_NUMBER() OVER (
				PARTITION BY ISNULL(RecordId, -1)  -- Agrupar NULL como -1
				ORDER BY 
					CASE SourceType 
						WHEN 'Role' THEN 1
						WHEN 'RoleRecord' THEN 2
						WHEN 'User' THEN 3
						WHEN 'UserRecord' THEN 4						
					END
			) AS RN
		FROM #EffectivePermissions
	) AS RankedPermissions
	WHERE RN = 1
	ORDER BY SourceType;

    DROP TABLE #EffectivePermissions;
END;
