IF OBJECT_ID('dbo.spza_GDSFacturacionAuto_InsertarLog', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spza_GDSFacturacionAuto_InsertarLog;
GO
CREATE PROCEDURE [dbo].[spza_GDSFacturacionAuto_InsertarLog] 
	-- Parametros del procedimiento
	@id_usuario		INT,
	@cd_sucursal	CHAR(5), 
	@dt_fecha		SMALLDATETIME,
	@ds_Mensaje		VARCHAR(MAX),
	@Id_reserva		INT,
	@cd_reserva		VARCHAR(10),
	@ds_archivo		VARCHAR(50) = NULL,
	@bl_error		BIT = 0,
	@cd_tiqueteador VARCHAR(6) = NULL,
	@ds_tipodoc		CHAR(2) = NULL, /*inicio rgelis 2014/11/20 req.22083*/
	@cd_fuentedoc	CHAR(2) = NULL,
	@cd_numerodoc	CHAR(2) = NULL	/*fin rgelis 2014/11/20 req.22083*/
 
AS
BEGIN
	-- SET NOCOUNT ON: Previene que conjuntos de resultados extras interfieran con 
	-- expresiones SELECT
	SET NOCOUNT ON;

    -- Declaracion e inicializacion de variables
  	DECLARE @bl_permit			 BIT 	, -- Permiso de ejecucion del proceso
  			@bl_as 	   			 BIT	, -- Auditar exito
	 		@bl_af 			     BIT	, -- Auditar fallido	 		
			@procmsg	VARCHAR(8000)	, -- Mensaje devuelto por procedimientos llamados desde este procedimiento
			@procret 	BIT 			, -- Valor de retorno de los procedimientos llamados desde este procedimiento
			@idproce	int		    	, -- Codigo de proceso
	 		@retry 		BIT			    , -- 1=Reintentar ; 0=Abortar  
	 		@retrycont	INT			    , -- Contador de reintentos
	 		@maxretries INT			    , -- Maximo numero de reintentos
	 		@timeout	NVARCHAR(4000)  , -- Tiempo de espera maximo por bloqueo de registros
	 		@stmt 		NVARCHAR(4000)  , -- Cadena de instrucciones T-SQL
			@msg	    VARCHAR(8000)   , -- Mensaje retornado por el sistema
			@retval		TINYINT 		; -- Valor de retorno de este procedimiento: 0:Exito ; 1:Error(Bloque Catch)
	
	SELECT 	@idproce 			 = 246,
			@retry				 = 1,
			@retrycont			 = 0,
			@retval				 = 0;
  	
  	-- Manejo de tiempo de espera y de reintentos por bloqueo de tablas/registros  
   	SELECT @maxretries = convert(INT,Valor) FROM dbo.Parametros WHERE Id = 60 ;
	SELECT @timeout    = convert(NVARCHAR(4000),Valor) FROM dbo.Parametros WHERE Id = 50 ;		
	SET @stmt = N'SET LOCK_TIMEOUT '+ltrim(rtrim(@timeout))
	EXEC sp_executesql @stmt,N''
	
	
	WHILE ( (@retry = 1) AND (@retrycont <= @maxretries) )
	BEGIN
		SET @retry = 0;
    
    	-- Bloque TRY
    	BEGIN TRY 
    	    		
    		--Obteniendo informacion de seguridad y auditoria--
			EXEC dbo.spzaProcesoUsuario_Consultar @id_usuario   = @id_usuario       ,
												  @id_proceso   = @idproce 		    , 
												  @bl_permit    = @bl_permit OUTPUT , 
												  @bl_auditsuc  = @bl_as 	 OUTPUT , 
												  @bl_auditfail = @bl_af 	 OUTPUT ;
			IF (@bl_permit = 0)
			BEGIN 
				SELECT 'No posee permisos suficientes para ejecutar esta acciÃ³n.' AS 'Respuesta'
				RETURN @retval;
			END 
			
			--Iniciando / salvando transaccion dependiendo si ya esta iniciada o no--
		  	BEGIN TRAN;
			
			--Instrucciones del procedimiento-----------------------------------------

			INSERT INTO dbo.ReservasGDS_FacAuto_log
				(
				cd_sucursal,
				dt_fecha,
				ds_Mensaje,
				cd_reserva,
				bl_error,
				ds_archivo,
				id_reserva, /*inicio rgelis 2014/10/02 req.22111*/
				id_usuario, 
				cd_tiqueteador, /*fin rgelis 2014/10/02 req.22111*/
				ds_tipodoc, /*inicio rgelis 2014/11/20 req.22083*/
				cd_fuentedoc,
				cd_numerodoc /*fin rgelis 2014/11/20 req.22083*/
				)
			VALUES 
				(
				@cd_sucursal,
				@dt_fecha,
				@ds_mensaje,
				@cd_reserva,
				@bl_error,
				@ds_archivo,
				@Id_reserva, /*inicio rgelis 2014/10/02 req.22111*/
				@id_usuario,	
				@cd_tiqueteador, /*fin rgelis 2014/10/02 req.22111*/
				@ds_tipodoc, /*inicio rgelis 2014/11/20 req.22083*/
				@cd_fuentedoc,
				@cd_numerodoc /*fin rgelis 2014/11/20 req.22083*/
				)	

			IF ISNULL(@ds_tipodoc,'') <> '' AND ISNULL(@ds_tipodoc,'') <> '' AND ISNULL(@ds_tipodoc,'') <> ''
			BEGIN 
				IF ISNULL(@ds_tipodoc,'') = 'FA'
				BEGIN 
					UPDATE lal
					SET bl_procesado = 1
					FROM dbo.Licitaciones_Alertas_Log lal
					INNER JOIN dbo.fac_factura ON fac_factura.id = lal.id_Documento
					WHERE lal.id_Sys_Entidades = 24  AND fac_factura.cd_fuente = @cd_fuentedoc and fac_factura.numero = @cd_numerodoc 
				END 
				ELSE IF ISNULL(@ds_tipodoc,'') = 'RM'
				BEGIN 
					UPDATE lal
					SET bl_procesado = 1
					FROM dbo.Licitaciones_Alertas_Log lal
					INNER JOIN dbo.fac_remision ON fac_remision.id = lal.id_Documento
					WHERE lal.id_Sys_Entidades = 25  AND fac_remision.cd_fuente = @cd_fuentedoc and fac_remision.numero = @cd_numerodoc 
				END 
			END
			 
			If @bl_error = 1
			Begin
				DELETE FROM dbo.ReservasGDS_FacAuto
				WHERE id_reserva = @id_reserva
			End
			Else
			Begin
				DELETE FROM dbo.ReservasGDS_FacAuto
				WHERE id_reserva = @id_reserva
				AND Id_reserva not in (Select Id_reserva From dbo.Reservagds_detalles Where Id_reserva = @id_reserva AND bl_usada = 0) --rgelis 2018/12/12 req.74918
			End
		
			--------------------------------------------------------------------------
			
			
			--Determinando si se debe auditar el proceso exitoso
			IF (@bl_as = 1) 
			BEGIN 										
				EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
												 @id_usuario = @id_usuario ,
												 @cd_status  = 1           , 												 
												 @admsg      = NULL        ,
							 					 @msgparams  = @msg;
			END 			 			
			
 		 	--Si la transaccion fue creada en el procedimiento entonces se actualiza--
			IF (@@TRANCOUNT > 0 AND XACT_STATE() <> 0)
			BEGIN 
				COMMIT TRAN;	
			END 
			
			SELECT ltrim(rtrim(@msg)) AS 'Respuesta';
			RETURN @retval;
	    END TRY 
    
    	-- Bloque CATCH (Manejo de excepciones)
    	BEGIN CATCH 

 			--Error de duplicado--
 			if error_number()= 2601
 			begin 
 				SET @msg =  'No se Pudo Crear el Cargo. Ya existe';
      			SET @retval = 1
   	        	
   	        	IF (@@TRANCOUNT > 0)
   	        	BEGIN 
					ROLLBACK;
	   	        END
	   	        
	   	        RAISERROR (@msg,16,124);
	   	      	--Se debe auditar proceso fallido
				IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce ,
													 			 @id_usuario = @id_usuario ,
													 			 @cd_status  = 0      , 
													 			 @admsg      = @msg	   ;				
	   	        RETURN @retval;
		    END
		     		
 			-- Tiempo de espera alcanzado --
		    IF ERROR_NUMBER() = 1222
		    BEGIN
      			SET @msg =  'No se pudo ejecutar el proceso. Tiempo de espera agotado.';
      			SET @retval = 1
   	        	
   	        	IF (@@TRANCOUNT > 0)
   	        	BEGIN 
					ROLLBACK;
	   	        END
	   	         
	   	        RAISERROR (@msg,16,125);
	   	       	--Se debe auditar proceso fallido
				IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce ,
													 			 @id_usuario = @id_usuario ,
													 			 @cd_status  = 0           , 
													 			 @admsg      = @msg	   ;				
	   	        RETURN @retval;
		    END
		    
		    -- Registro bloqueado / Conflicto de actualizacion
		    ELSE IF ERROR_NUMBER() IN (1205, 3960)
    		BEGIN
    			IF (@@TRANCOUNT > 0)
   	        	BEGIN 
					ROLLBACK;
	   	        END
	   	        
		       	SET @retry     = 1              ;
		       	SET @retrycont = @retrycont + 1 ; 

	    	 END
	    	 ELSE
		     BEGIN
		     	-- Error no manejado --

   	        	IF (@@TRANCOUNT > 0)
   	        	BEGIN 
					ROLLBACK;
	   	        END
													
				SET @retval = 1;
 				SET @msg =	'Ha ocurrido un error. InformaciÃ³n para soporte tecnico:'			+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
						    'Numero: ' + isnull(CAST(ERROR_NUMBER()   AS VARCHAR(10)),'') 		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							'Mensaje: ' + isnull(ERROR_MESSAGE(),'') 					   		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
						 	'Severidad: ' + isnull(CAST(ERROR_SEVERITY() AS VARCHAR(10)),'') 	+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
						 	'Estado: ' + isnull(CAST(ERROR_STATE()    AS VARCHAR(10)),'') 		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							'Procedimiento: ' + isnull(ERROR_PROCEDURE(),'')					+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							'Linea: ' + isnull(CAST(ERROR_LINE() 	   AS VARCHAR(10)),''); 							
	
				RAISERROR (@msg,16,126);
				--Se debe auditar proceso fallido
				IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar	@id_proceso = @idproce   ,
										 			 			@id_usuario = @id_usuario ,
										 			 			@cd_status  = 0           , 
										 			 			@admsg      = @msg	  ;				
				RETURN @retval;

		     END
		END CATCH     
	END 
	
	IF (@retrycont>@maxretries) 
	BEGIN 
		SET @retval = 1
		SET @msg = 'No se pudo finalizar el proceso. Maximo numero de reintentos alcanzado.'
		--Se debe auditar proceso fallido
		IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
											 			 @id_usuario = @id_usuario ,
											 			 @cd_status  = 0           , 
											 			 @admsg      = @msg	   ;												 	   					   
  		RAISERROR (@msg,16,127);
  		RETURN @retval;
  	END   	
    
    RETURN @retval;
END
GO
