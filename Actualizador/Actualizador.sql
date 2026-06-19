IF OBJECT_ID('dbo.spza_CargosImpAsignadosIntegradoJOB_ConsultarConceptoFac', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spza_CargosImpAsignadosIntegradoJOB_ConsultarConceptoFac;
GO
CREATE PROCEDURE [dbo].[spza_CargosImpAsignadosIntegradoJOB_ConsultarConceptoFac] 
	-- Parametros del procedimiento
	@id_usuario INT,
	@id_ConceptFac INT,
	@bu VARCHAR(25) = '',
	@Id_Cliente Varchar(25) = NULL 

 
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
	
	SELECT 	@retry				 = 1 		   ,
			@retrycont			 = 0		   ,
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
    	   	
			--Instrucciones del procedimiento-----------------------------------------
			DECLARE @id_TiposConceptoFacturacion INT
			SELECT @id_TiposConceptoFacturacion = ConceptoFacturacion.id_TiposConceptoFacturacion FROM dbo.ConceptoFacturacion WHERE ConceptoFacturacion.id = @id_ConceptFac

			IF ISNULL(@bu,'')=''
			BEGIN
				SELECT @bu = CASE WHEN ISNULL(I.cd_bu,'')<>'' THEN I.cd_bu ELSE ISNULL(S.cd_bu,'') END 
				From dbo.Usuario U
				Left Join [dbo].[Sucursales] S On U.id_sucursal = S.id
				Left Join [dbo].[Implantes] I On U.id_implante = I.id
				WHERE U.id=@id_usuario
			END

			--TODO: Manejo de cargos e impuestos por BU
			DECLARE @Permite_BU AS CHAR(2), @am_valor MONEY				
			SELECT @Permite_BU = rtrim(valor) FROM Parametros  WHERE id = 163
			SELECT @am_valor = am_valor FROM dbo.ConfiguracionClientesConceptos WHERE id_cliente = @Id_Cliente AND id_ConceptoFacturacion=@id_ConceptFac AND bl_inactivo=0
			SET @am_valor = ISNULL(@am_valor,0)
			IF @Permite_BU = 'S'
			BEGIN
				SELECT DISTINCT Codigo
				 	,Concepto
				 	,Porcentaje
				 	,Editable
				 	,Calcular
				 	,Contado
				 	,Credito
				 	,Valor
				 	,id_carg
				 	,id_imp
				 	,Tipo
				 	,Nombre
				 	,Cuenta
				 	,Contabilizar
				 	,NULL AS 'Respuesta'
				 	,noshow 
				 	,id_cargo_dep
				 	,id_imp_dep	   
 				 	,C_Orden
				 	,I_Orden
					,bl_iva
					,bl_iva2
				 FROM (
				 		SELECT 	 CD.cd_codigo 				AS 'Codigo'
							 	,cd.ds_nombre   			AS 'Concepto'
							 	,convert(NUMERIC(8,4),0)	AS 'Porcentaje'
							 	,'S'						AS 'Editable'
							 	,'N/A'						AS 'Calcular'
							 	,CASE WHEN ISNULL(CC.am_valor,0)<>0 AND CD.id=1 THEN CC.am_valor ELSE CD.am_valdef END AS 'Contado' --rgelis 2020/09/30 req.141927
							 	,convert(money,0)			AS 'Credito'
							 	,CASE WHEN ISNULL(CC.am_valor,0)<>0 AND CD.id=1 THEN CC.am_valor ELSE CD.am_valdef END AS 'Valor' --rgelis 2020/09/30 req.141927
								,CD.id 						AS 'id_carg'
								,0							AS 'id_imp'
								,'Tipo'= CASE CD.cd_signo 
											WHEN '+' THEN 'C'
											WHEN '-' THEN 'D'
										 END 				 
								,cd.ds_nombre 				AS 'Nombre'   
								,replicate(' ',16)			AS 'Cuenta'
								,convert(BIT,0)				AS 'Contabilizar'
								,cd.bl_noshow 				AS 'noshow'
								,0 							AS 'id_cargo_dep'
								,0 							AS 'id_imp_dep'																
								,in_Orden 					AS 'C_Orden'
								,0		 					AS 'I_Orden'
								,0		 					AS 'bl_iva'
								,0		 					AS 'bl_iva2'
						FROM dbo.CargosAsignados_ConceptoFac C 
							INNER JOIN dbo.CargosDesc CD ON (C.id_CargosDesc = CD.id)
							LEFT JOIN dbo.ConfiguracionClientesConceptos CC ON CC.id_conceptofacturacion=C.id_ConceptoFac AND CC.Id_Cliente = @Id_Cliente AND CC.bl_inactivo=0
						WHERE C.id_ConceptoFac = @id_ConceptFac
						AND CD.id NOT IN (	--Excluimos cargos que ya estan en descuentos de clientes.
											SELECT cd.Id
											FROM dbo.Configuracion_remisiones C 
												INNER JOIN dbo.Clientes_Descuentos CDSC ON CDSC.Id_Configuracion_remisiones = C.Id --And CDSC.id_ConceptoFacturacion IS NOT NULL
												INNER JOIN dbo.CargosDesc CD ON CD.id = CDSC.id_CargosDesc
											WHERE C.Id_Cliente = @Id_Cliente AND  (CDSC.id_ConceptoFacturacion = @id_ConceptFac OR CDSC.id_ConceptoFacturacion IS NULL)	
											)
						AND NOT EXISTS (
											SELECT cd.id
											FROM dbo.CLIENTES cl
												INNER JOIN dbo.TERCEROS t ON t.IDTERCERO = cl.IDTERCERO
												INNER JOIN dbo.Configuracion_ImpCategoriaFiscal CC ON CC.TipoEmpresa = t.TIPOEMPRESA
												INNER JOIN dbo.CargosAsignados_Configuracion_ImpCategoriaFiscal C ON C.id_Configuracion_ImpCategoriaFiscal =  CC.id
												INNER JOIN dbo.CargosDesc CD ON (C.id_CargosDesc = CD.id)
											WHERE cl.IDCLIENTE = @Id_Cliente AND CC.id_TiposConceptFac = @id_TiposConceptoFacturacion
										)

						UNION ALL
						
						SELECT 
								 IR.cd_codigo 										AS 'Codigo'
							 	,IR.ds_alias	   									AS 'Concepto'
							 	,ISNULL(convert(NUMERIC(8,4),IBU.am_porcentaje),0)	AS 'Porcentaje'
							 	,'Editable' = CASE IR.bl_editar 
												WHEN 0 THEN 'N'
												WHEN 1 THEN 'S'
									  		  END   
							 	,'Calcular'											AS 'Calcular'
							 	,CASE WHEN ISNULL(CC.am_valor,0)<>0 AND CD.id=1 AND IR.id_cargo_dep=1 AND IR.am_porcentaje>0 THEN convert(money,CC.am_valor*(IR.am_porcentaje/100)) ELSE convert(money,0) END AS 'Contado'
							 	,convert(money,0)									AS 'Credito'
							 	,CASE WHEN ISNULL(CC.am_valor,0)<>0 AND CD.id=1 AND IR.id_cargo_dep=1 AND IR.am_porcentaje>0 THEN convert(money,CC.am_valor*(IR.am_porcentaje/100)) ELSE convert(money,0) END AS 'Valor'
								,C.id_CargosDesc					   				AS 'id_carg'
								,I.id_ImpRet										AS 'id_imp'
								,'Tipo'= CASE IR.cd_tipo 
											WHEN 0 THEN 'I'
											WHEN 1 THEN 'R'
										 END     
								,IR.ds_nombre 						   				AS 'Nombre'   
								,IR.cd_cuenta										AS 'Cuenta'
								,bl_contabilizar									AS 'Contabilizar'
								,convert(BIT,0)										AS 'noshow'
								,isnull(IR.id_cargo_dep,0)                          AS 'id_cargo_dep'
								,isnull(IR.id_imp_dep,0)							AS 'id_imp_dep'
								,C.in_orden											AS 'C_Orden'
								,i.in_Orden		 	   								AS 'I_Orden'
								,bl_iva
								,bl_iva2
						FROM dbo.CargosAsignados_ConceptoFac C 
							INNER JOIN dbo.CargosDesc CD ON (C.id_CargosDesc = CD.id)
							LEFT JOIN dbo.ConfiguracionClientesConceptos CC ON CC.id_conceptofacturacion=C.id_ConceptoFac AND CC.Id_Cliente = @Id_Cliente AND CC.bl_inactivo=0
							LEFT JOIN dbo.ImpAsignados_ConceptoFac I ON (C.id = I.id_CargosAsignados_ConceptoFac)
							LEFT JOIN dbo.ImpRet IR ON (I.id_ImpRet = IR.id)
							LEFT JOIN dbo.Impuestos_bu IBU ON (IBU.id_impuesto = IR.id AND ibu.cd_bu = @bu )
						WHERE C.id_ConceptoFac = @id_ConceptFac
						AND NOT EXISTS (
												SELECT IR.id
												FROM dbo.CLIENTES cl
													INNER JOIN dbo.TERCEROS t ON t.IDTERCERO = cl.IDTERCERO
													INNER JOIN dbo.Configuracion_ImpCategoriaFiscal CC ON CC.TipoEmpresa = t.TIPOEMPRESA
													INNER JOIN dbo.CargosAsignados_Configuracion_ImpCategoriaFiscal C ON C.id_Configuracion_ImpCategoriaFiscal =  CC.id
													INNER JOIN dbo.CargosDesc CD ON (C.id_CargosDesc = CD.id)
													INNER JOIN dbo.ImpAsignados_Configuracion_ImpCategoriaFiscal I ON (I.id_CargosAsignados_Configuracion_ImpCategoriaFiscal = C.id )
													INNER JOIN dbo.ImpRet IR ON (I.id_ImpRet = IR.id)
													INNER JOIN dbo.Impuestos_bu IBU ON (IBU.id_impuesto = IR.id AND ibu.cd_bu = @bu )
												WHERE cl.IDCLIENTE = @Id_Cliente AND CC.id_TiposConceptFac = @id_TiposConceptoFacturacion
												)

						UNION ALL 
						--Cargos por categoria fiscal del cliente
				 		SELECT 	 CD.cd_codigo 				AS 'Codigo'
							 	,cd.ds_nombre   			AS 'Concepto'
							 	,convert(NUMERIC(8,4),0)	AS 'Porcentaje'
							 	,'S'						AS 'Editable'
							 	,'N/A'						AS 'Calcular'
							 	,CD.am_valdef    			AS 'Contado'
							 	,convert(money,0)			AS 'Credito'
							 	,CD.am_valdef				AS 'Valor'
								,CD.id 						AS 'id_carg'
								,0							AS 'id_imp'
								,'Tipo'= CASE CD.cd_signo 
											WHEN '+' THEN 'C'
											WHEN '-' THEN 'D'
										 END 				 
								,cd.ds_nombre 				AS 'Nombre'   
								,replicate(' ',16)			AS 'Cuenta'
								,convert(BIT,0)				AS 'Contabilizar'
								,cd.bl_noshow 				AS 'noshow'
								,0 							AS 'id_cargo_dep'
								,0 							AS 'id_imp_dep'																
								,in_Orden 					AS 'C_Orden'
								,0		 					AS 'I_Orden'		
								,0		 					AS 'bl_iva'
								,0		 					AS 'bl_iva2'																						
						FROM dbo.CLIENTES cl
							INNER JOIN dbo.TERCEROS t ON t.IDTERCERO = cl.IDTERCERO
							INNER JOIN dbo.Configuracion_ImpCategoriaFiscal CC ON CC.TipoEmpresa = t.TIPOEMPRESA
							INNER JOIN dbo.CargosAsignados_Configuracion_ImpCategoriaFiscal C ON C.id_Configuracion_ImpCategoriaFiscal =  CC.id
							INNER JOIN dbo.CargosDesc CD ON (C.id_CargosDesc = CD.id)
						WHERE cl.IDCLIENTE = @Id_Cliente AND CC.id_TiposConceptFac = @id_TiposConceptoFacturacion
						--AND CD.id NOT IN (
						--					SELECT CD.id
						--					FROM dbo.CargosAsignados_ConceptoFac C 
						--						INNER JOIN dbo.CargosDesc CD ON (C.id_CargosDesc = CD.id)
						--					WHERE C.id_ConceptoFac = @id_ConceptFac
						--				)	

						UNION ALL 
						--Impuestos por categoria fiscal del cliente
						SELECT 
								 IR.cd_codigo 										AS 'Codigo'
							 	,IR.ds_alias	   									AS 'Concepto'
							 	,ISNULL(convert(NUMERIC(8,4),IBU.am_porcentaje),0)	AS 'Porcentaje'
							 	,'Editable' = CASE IR.bl_editar 
												WHEN 0 THEN 'N'
												WHEN 1 THEN 'S'
									  		  END   
							 	,'Calcular'											AS 'Calcular'
							 	,convert(money,0)									AS 'Contado'
							 	,convert(money,0)									AS 'Credito'
							 	,convert(money,0)									AS 'Valor'
								,C.id_CargosDesc					   				AS 'id_carg'
								,I.id_ImpRet										AS 'id_imp'
								,'Tipo'= CASE IR.cd_tipo 
											WHEN 0 THEN 'I'
											WHEN 1 THEN 'R'
										 END     
								,IR.ds_nombre 						   				AS 'Nombre'   
								,IR.cd_cuenta										AS 'Cuenta'
								,bl_contabilizar									AS 'Contabilizar'
								,convert(BIT,0)										AS 'noshow'
								,isnull(IR.id_cargo_dep,0)                          AS 'id_cargo_dep'
								,isnull(IR.id_imp_dep,0)							AS 'id_imp_dep'
								,C.in_orden											AS 'C_Orden'
								,i.in_Orden		 	   								AS 'I_Orden'
								,bl_iva
								,bl_iva2
						FROM dbo.CLIENTES cl
							INNER JOIN dbo.TERCEROS t ON t.IDTERCERO = cl.IDTERCERO
							INNER JOIN dbo.Configuracion_ImpCategoriaFiscal CC ON CC.TipoEmpresa = t.TIPOEMPRESA
							INNER JOIN dbo.CargosAsignados_Configuracion_ImpCategoriaFiscal C ON C.id_Configuracion_ImpCategoriaFiscal =  CC.id
							INNER JOIN dbo.CargosDesc CD ON (C.id_CargosDesc = CD.id)
							INNER JOIN dbo.ImpAsignados_Configuracion_ImpCategoriaFiscal I ON (I.id_CargosAsignados_Configuracion_ImpCategoriaFiscal = C.id )
							INNER JOIN dbo.ImpRet IR ON (I.id_ImpRet = IR.id)
							INNER JOIN dbo.Impuestos_bu IBU ON (IBU.id_impuesto = IR.id AND ibu.cd_bu = @bu )
						WHERE cl.IDCLIENTE = @Id_Cliente AND CC.id_TiposConceptFac = @id_TiposConceptoFacturacion
						--AND ibu.id_impuesto NOT IN (
						--							SELECT ibu.id_impuesto
						--							FROM dbo.CargosAsignados_ConceptoFac C 
						--								INNER JOIN dbo.CargosDesc CD ON (C.id_CargosDesc = CD.id)
						--								LEFT JOIN dbo.ImpAsignados_ConceptoFac I ON (C.id = I.id_CargosAsignados_ConceptoFac)
						--								LEFT JOIN dbo.ImpRet IR ON (I.id_ImpRet = IR.id)
						--								LEFT JOIN dbo.Impuestos_bu IBU ON (IBU.id_impuesto = IR.id AND ibu.cd_bu = @bu )
						--							WHERE C.id_ConceptoFac = @id_ConceptFac
						--							)
										
						UNION ALL
						--Descuentos de Clientes
				 		SELECT 	 CD.cd_codigo 							AS 'Codigo'
							 	,cd.ds_nombre   						AS 'Concepto'
							 	,convert(NUMERIC(8,4),CDSC.am_porcentaje)	AS 'Porcentaje'
							 	,'S'									AS 'Editable'
							 	,CASE 
							 		WHEN CDSC.am_porcentaje > 0 THEN 'Calcular'								
							 		ELSE 'N/A' END 
							 		AS 'Calcular'
							 	,CDSC.am_valor    						AS 'Contado'
							 	,convert(money,0)						AS 'Credito'
							 	,CDSC.am_valor							AS 'Valor'
								,CD.id 									AS 'id_carg'
								,0										AS 'id_imp'
								,'Tipo'= CASE CD.cd_signo 
											WHEN '+' THEN 'C'
											WHEN '-' THEN 'D'
										 END 				 
								,cd.ds_nombre 							AS 'Nombre'   
								,replicate(' ',16)						AS 'Cuenta'
								,convert(BIT,0)							AS 'Contabilizar'
								,cd.bl_noshow 							AS 'noshow'
								,isnull(cd.id_cargo_dep,0) 				AS 'id_cargo_dep'
								,0 										AS 'id_imp_dep'
								,999	 								AS 'C_Orden'
								,0		 								AS 'I_Orden'
								,0		 								AS 'bl_iva'
								,0		 								AS 'bl_iva2'
						FROM dbo.Configuracion_remisiones C 
							INNER JOIN dbo.Clientes_Descuentos CDSC ON CDSC.Id_Configuracion_remisiones = C.Id --And CDSC.id_ConceptoFacturacion IS NOT NULL
							INNER JOIN dbo.CargosDesc CD ON CD.id = CDSC.id_CargosDesc
						WHERE C.Id_Cliente = @Id_Cliente AND  (CDSC.id_ConceptoFacturacion = @id_ConceptFac OR CDSC.id_ConceptoFacturacion IS NULL)

						/*UNION ALL
						-- Asignacion de por tipo de concepto facturacion
						SELECT  CD.cd_codigo 				AS 'Codigo'
							 	,CD.ds_nombre   			AS 'Concepto'
							 	,convert(NUMERIC(8,4),0)	AS 'Porcentaje'
							 	,'S'						AS 'Editable'
							 	,'N/A'						AS 'Calcular'
							 	,CD.am_valdef    			AS 'Contado'
							 	,convert(money,0)			AS 'Credito'
							 	,CD.am_valdef				AS 'Valor'
								,CD.id 						AS 'id_carg'
								,0							AS 'id_imp'
								,'Tipo'= CASE CD.cd_signo 
											WHEN '+' THEN 'C'
											WHEN '-' THEN 'D'
										 END 				 
								,CD.ds_nombre 				AS 'Nombre'   
								,replicate(' ',16)			AS 'Cuenta'
								,convert(BIT,0)				AS 'Contabilizar'
								,cd.bl_noshow 				AS 'noshow'
								,0 							AS 'id_cargo_dep'
								,0 							AS 'id_imp_dep'																
								,C.in_Orden 				AS 'C_Orden'
								,0		 					AS 'I_Orden'		
								,0		 					AS 'bl_iva'
								,0		 					AS 'bl_iva2'
						FROM dbo.ConceptoFacturacion CF
						INNER JOIN dbo.CargosAsignados C ON C.id_TiposConceptFac = CF.id_TiposConceptoFacturacion
						INNER JOIN dbo.CargosDesc CD ON CD.id = C.id_CargosDesc
						WHERE CF.id = @id_ConceptFac AND CF.bl_contorlarCargImp=0	
						
						UNION ALL
						
						SELECT IR.cd_codigo 										AS 'Codigo'
							 	,IR.ds_alias	   									AS 'Concepto'
							 	,ISNULL(convert(NUMERIC(8,4),IR.am_porcentaje),0)	AS 'Porcentaje'
							 	,'Editable' = CASE IR.bl_editar 
												WHEN 0 THEN 'N'
												WHEN 1 THEN 'S'
									  		  END   
							 	,'Calcular'											AS 'Calcular'
							 	,convert(money,0)									AS 'Contado'
							 	,convert(money,0)									AS 'Credito'
							 	,convert(money,0)									AS 'Valor'
								,C.id_CargosDesc					   				AS 'id_carg'
								,I.id_ImpRet										AS 'id_imp'
								,'Tipo'= CASE IR.cd_tipo 
											WHEN 0 THEN 'I'
											WHEN 1 THEN 'R'
										 END     
								,IR.ds_nombre 						   				AS 'Nombre'   
								,IR.cd_cuenta										AS 'Cuenta'
								,IR.bl_contabilizar									AS 'Contabilizar'
								,convert(BIT,0)										AS 'noshow'
								,isnull(IR.id_cargo_dep,0)                          AS 'id_cargo_dep'
								,isnull(IR.id_imp_dep,0)							AS 'id_imp_dep'
								,C.in_orden											AS 'C_Orden'
								,i.in_Orden		 	   								AS 'I_Orden'
								,bl_iva
								,bl_iva2
						FROM dbo.ConceptoFacturacion CF
						INNER JOIN dbo.CargosAsignados C ON C.id_TiposConceptFac = CF.id_TiposConceptoFacturacion
						INNER JOIN dbo.CargosDesc CD ON CD.id = C.id_CargosDesc
						INNER JOIN  dbo.ImpAsignados I ON I.id_CargosAsignados = C.id
						INNER JOIN dbo.ImpRet IR ON IR.id = I.id_ImpRet
						WHERE CF.id = @id_ConceptFac AND CF.bl_contorlarCargImp=0 
						*/							

				 	) AS temptbl
				 WHERE Codigo IS NOT NULL 
				 ORDER BY C_Orden, I_Orden ,Id_carg,Id_imp
			END 
			ELSE
			BEGIN
				SELECT 	DISTINCT Codigo
				 	,Concepto
				 	,Porcentaje
				 	,Editable
				 	,Calcular
				 	,Contado
				 	,Credito
				 	,Valor
				 	,id_carg
				 	,id_imp
				 	,Tipo
				 	,Nombre
				 	,Cuenta
				 	,Contabilizar
				 	,NULL AS 'Respuesta'
				 	,noshow 
				 	,id_cargo_dep
				 	,id_imp_dep	   
 				 	,C_Orden
				 	,I_Orden
					,bl_iva
					,bl_iva2
				 FROM (
				 		SELECT 	 CD.cd_codigo 				AS 'Codigo'
							 	,cd.ds_nombre   			AS 'Concepto'
							 	,convert(NUMERIC(8,4),am_porcentaje)	AS 'Porcentaje'
							 	,'S'						AS 'Editable'
							 	,CASE 
							 		WHEN am_porcentaje > 0 THEN 'Calcular'								
							 		ELSE 'N/A' END 
							 		AS 'Calcular'
							 	,CASE WHEN ISNULL(CC.am_valor,0)<>0 AND CD.id=1 THEN CC.am_valor ELSE CD.am_valdef END AS 'Contado'
							 	,convert(money,0)			AS 'Credito'
							 	,CASE WHEN ISNULL(CC.am_valor,0)<>0 AND CD.id=1 THEN CC.am_valor ELSE CD.am_valdef END AS 'Valor'
								,CD.id 						AS 'id_carg'
								,0							AS 'id_imp'
								,'Tipo'= CASE CD.cd_signo 
											WHEN '+' THEN 'C'
											WHEN '-' THEN 'D'
										 END 				 
								,cd.ds_nombre 				AS 'Nombre'   
								,replicate(' ',16)			AS 'Cuenta'
								,convert(BIT,0)				AS 'Contabilizar'
								,cd.bl_noshow 				AS 'noshow'
								,isnull(cd.id_cargo_dep,0) 	AS 'id_cargo_dep'
								,0 							AS 'id_imp_dep'																
								,in_Orden 					AS 'C_Orden'
								,0		 					AS 'I_Orden'
								,0		 					AS 'bl_iva'
								,0		 					AS 'bl_iva2'
							FROM dbo.CargosAsignados_ConceptoFac C 
								INNER JOIN dbo.CargosDesc CD ON (C.id_CargosDesc = CD.id)
								LEFT JOIN dbo.ConfiguracionClientesConceptos CC ON CC.id_conceptofacturacion=C.id_ConceptoFac AND CC.Id_Cliente = @Id_Cliente AND CC.bl_inactivo=0
							WHERE C.id_ConceptoFac = @id_ConceptFac
							AND CD.id NOT IN (	--Excluimos cargos que ya estan en descuentos de clientes.
												SELECT cd.Id
												FROM dbo.Configuracion_remisiones C 
													INNER JOIN dbo.Clientes_Descuentos CDSC ON CDSC.Id_Configuracion_remisiones = C.Id --And CDSC.id_ConceptoFacturacion IS NOT NULL
													INNER JOIN dbo.CargosDesc CD ON CD.id = CDSC.id_CargosDesc
												WHERE C.Id_Cliente = @Id_Cliente AND  (CDSC.id_ConceptoFacturacion = @id_ConceptFac OR CDSC.id_ConceptoFacturacion IS NULL)
											  )
						AND NOT EXISTS (
										SELECT cd.id
										FROM dbo.CLIENTES cl
											INNER JOIN dbo.TERCEROS t ON t.IDTERCERO = cl.IDTERCERO
											INNER JOIN dbo.Configuracion_ImpCategoriaFiscal CC ON CC.TipoEmpresa = t.TIPOEMPRESA
											INNER JOIN dbo.CargosAsignados_Configuracion_ImpCategoriaFiscal C ON C.id_Configuracion_ImpCategoriaFiscal =  CC.id
											INNER JOIN dbo.CargosDesc CD ON (C.id_CargosDesc = CD.id)
										WHERE cl.IDCLIENTE = @Id_Cliente AND CC.id_TiposConceptFac = @id_TiposConceptoFacturacion
										)

						UNION ALL
						
						SELECT 
								 IR.cd_codigo 							AS 'Codigo'
							 	,IR.ds_alias	   						AS 'Concepto'
							 	,convert(NUMERIC(8,4),IR.am_porcentaje)	AS 'Porcentaje'
							 	,'Editable' = CASE IR.bl_editar 
												WHEN 0 THEN 'N'
												WHEN 1 THEN 'S'
									  		  END   
							 	,'Calcular'								AS 'Calcular'
							 	,CASE WHEN ISNULL(CC.am_valor,0)<>0 AND CD.id=1 AND IR.id_cargo_dep=1 AND IR.am_porcentaje>0 THEN convert(money,CC.am_valor*(IR.am_porcentaje/100)) ELSE convert(money,0) END AS 'Contado'
							 	,convert(money,0)						AS 'Credito'
							 	,CASE WHEN ISNULL(CC.am_valor,0)<>0 AND CD.id=1 AND IR.id_cargo_dep=1 AND IR.am_porcentaje>0 THEN convert(money,CC.am_valor*(IR.am_porcentaje/100)) ELSE convert(money,0) END AS 'Valor'
								,C.id_CargosDesc						AS 'id_carg'
								,I.id_ImpRet							AS 'id_imp'
								,'Tipo'= CASE IR.cd_tipo 
											WHEN 0 THEN 'I'
											WHEN 1 THEN 'R'
										 END     
								,IR.ds_nombre 							AS 'Nombre'   
								,IR.cd_cuenta							AS 'Cuenta'
								,bl_contabilizar						AS 'Contabilizar'
								,convert(BIT,0)							AS 'noshow'
								,isnull(IR.id_cargo_dep,0) /*  isnull(c.id_CargosDesc,0) */                    AS 'id_cargo_dep' --rgelis 2017/02/11 se cambia por error en superdestinos
								,isnull(IR.id_imp_dep,0)							AS 'id_imp_dep'
								,C.in_orden											AS 'C_Orden'
								,i.in_Orden		 	   								AS 'I_Orden'
								,bl_iva
								,bl_iva2
							FROM dbo.CargosAsignados_ConceptoFac C 
								INNER JOIN dbo.CargosDesc CD ON (C.id_CargosDesc = CD.id)
								LEFT JOIN dbo.ConfiguracionClientesConceptos CC ON CC.id_conceptofacturacion=C.id_ConceptoFac AND CC.Id_Cliente = @Id_Cliente AND CC.bl_inactivo=0
								LEFT JOIN dbo.ImpAsignados_ConceptoFac I ON (C.id = I.id_CargosAsignados_ConceptoFac)
								LEFT JOIN dbo.ImpRet IR ON (I.id_ImpRet = IR.id)
							WHERE C.id_ConceptoFac = @id_ConceptFac
							AND NOT EXISTS(
											SELECT IR.id
											FROM dbo.CLIENTES cl
												INNER JOIN dbo.TERCEROS t ON t.IDTERCERO = cl.IDTERCERO
												INNER JOIN dbo.Configuracion_ImpCategoriaFiscal CC ON CC.TipoEmpresa = t.TIPOEMPRESA
												INNER JOIN dbo.CargosAsignados_Configuracion_ImpCategoriaFiscal C ON C.id_Configuracion_ImpCategoriaFiscal =  CC.id
												INNER JOIN dbo.CargosDesc CD ON (C.id_CargosDesc = CD.id)
												INNER JOIN dbo.ImpAsignados_Configuracion_ImpCategoriaFiscal I ON (I.id_CargosAsignados_Configuracion_ImpCategoriaFiscal = C.id )
												INNER JOIN dbo.ImpRet IR ON (I.id_ImpRet = IR.id)
											WHERE cl.IDCLIENTE = @Id_Cliente AND CC.id_TiposConceptFac = @id_TiposConceptoFacturacion
										   )

						UNION ALL 
						--Cargos por categoria fiscal del cliente
				 		SELECT 	 CD.cd_codigo 				AS 'Codigo'
							 	,cd.ds_nombre   			AS 'Concepto'
							 	,convert(NUMERIC(8,4),0)	AS 'Porcentaje'
							 	,'S'						AS 'Editable'
							 	,'N/A'						AS 'Calcular'
							 	,CD.am_valdef    			AS 'Contado'
							 	,convert(money,0)			AS 'Credito'
							 	,CD.am_valdef				AS 'Valor'
								,CD.id 						AS 'id_carg'
								,0							AS 'id_imp'
								,'Tipo'= CASE CD.cd_signo 
											WHEN '+' THEN 'C'
											WHEN '-' THEN 'D'
										 END 				 
								,cd.ds_nombre 				AS 'Nombre'   
								,replicate(' ',16)			AS 'Cuenta'
								,convert(BIT,0)				AS 'Contabilizar'
								,cd.bl_noshow 				AS 'noshow'
								,0 							AS 'id_cargo_dep'
								,0 							AS 'id_imp_dep'																
								,in_Orden 					AS 'C_Orden'
								,0		 					AS 'I_Orden'			
								,0		 					AS 'bl_iva'
								,0		 					AS 'bl_iva2'																					
						FROM dbo.CLIENTES cl
							INNER JOIN dbo.TERCEROS t ON t.IDTERCERO = cl.IDTERCERO
							INNER JOIN dbo.Configuracion_ImpCategoriaFiscal CC ON CC.TipoEmpresa = t.TIPOEMPRESA
							INNER JOIN dbo.CargosAsignados_Configuracion_ImpCategoriaFiscal C ON C.id_Configuracion_ImpCategoriaFiscal =  CC.id
							INNER JOIN dbo.CargosDesc CD ON (C.id_CargosDesc = CD.id)
						WHERE cl.IDCLIENTE = @Id_Cliente AND CC.id_TiposConceptFac = @id_TiposConceptoFacturacion
						--AND CD.id NOT IN (
						--					SELECT Cd.id
						--					FROM dbo.CargosAsignados_ConceptoFac C 
						--						INNER JOIN dbo.CargosDesc CD ON (C.id_CargosDesc = CD.id)
						--					WHERE C.id_ConceptoFac = @id_ConceptFac										
						--					)						

						UNION ALL 
						--Impuestos por categoria fiscal del cliente
						SELECT 
								 IR.cd_codigo 										AS 'Codigo'
							 	,IR.ds_alias	   									AS 'Concepto'
							 	,convert(NUMERIC(8,4),IR.am_porcentaje)	AS 'Porcentaje'
							 	,'Editable' = CASE IR.bl_editar 
												WHEN 0 THEN 'N'
												WHEN 1 THEN 'S'
									  		  END   
							 	,'Calcular'											AS 'Calcular'
							 	,convert(money,0)									AS 'Contado'
							 	,convert(money,0)									AS 'Credito'
							 	,convert(money,0)									AS 'Valor'
								,C.id_CargosDesc					   				AS 'id_carg'
								,I.id_ImpRet										AS 'id_imp'
								,'Tipo'= CASE IR.cd_tipo 
											WHEN 0 THEN 'I'
											WHEN 1 THEN 'R'
										 END     
								,IR.ds_nombre 						   				AS 'Nombre'   
								,IR.cd_cuenta										AS 'Cuenta'
								,bl_contabilizar									AS 'Contabilizar'
								,convert(BIT,0)										AS 'noshow'
								,isnull(IR.id_cargo_dep,0)                          AS 'id_cargo_dep'
								,isnull(IR.id_imp_dep,0)							AS 'id_imp_dep'
								,C.in_orden											AS 'C_Orden'
								,i.in_Orden		 	   								AS 'I_Orden'
								,bl_iva
								,bl_iva2
						FROM dbo.CLIENTES cl
							INNER JOIN dbo.TERCEROS t ON t.IDTERCERO = cl.IDTERCERO
							INNER JOIN dbo.Configuracion_ImpCategoriaFiscal CC ON CC.TipoEmpresa = t.TIPOEMPRESA
							INNER JOIN dbo.CargosAsignados_Configuracion_ImpCategoriaFiscal C ON C.id_Configuracion_ImpCategoriaFiscal =  CC.id
							INNER JOIN dbo.CargosDesc CD ON (C.id_CargosDesc = CD.id)
							INNER JOIN dbo.ImpAsignados_Configuracion_ImpCategoriaFiscal I ON (I.id_CargosAsignados_Configuracion_ImpCategoriaFiscal = C.id )
							INNER JOIN dbo.ImpRet IR ON (I.id_ImpRet = IR.id)
						WHERE cl.IDCLIENTE = @Id_Cliente AND CC.id_TiposConceptFac = @id_TiposConceptoFacturacion
						--AND IR.id NOT IN (
						--					SELECT IR.id 
						--					FROM dbo.CargosAsignados_ConceptoFac C 
						--						INNER JOIN dbo.CargosDesc CD ON (C.id_CargosDesc = CD.id)
						--						LEFT JOIN dbo.ImpAsignados_ConceptoFac I ON (C.id = I.id_CargosAsignados_ConceptoFac)
						--						LEFT JOIN dbo.ImpRet IR ON (I.id_ImpRet = IR.id)
						--					WHERE C.id_ConceptoFac = @id_ConceptFac					
						--				)						

						UNION ALL
						-- descuentos configurados a cliente
				 		SELECT 	 CD.cd_codigo 							AS 'Codigo'
							 	,cd.ds_nombre   						AS 'Concepto'
							 	,convert(NUMERIC(8,4),CDSC.am_porcentaje)	AS 'Porcentaje'
							 	,'S'									AS 'Editable'
							 	,CASE 
							 		WHEN CDSC.am_porcentaje > 0 THEN 'Calcular'								
							 		ELSE 'N/A' END 
							 		AS 'Calcular'
							 	,CDSC.am_valor    						AS 'Contado'
							 	,convert(money,0)						AS 'Credito'
							 	,CDSC.am_valor							AS 'Valor'
								,CD.id 									AS 'id_carg'
								,0										AS 'id_imp'
								,'Tipo'= CASE CD.cd_signo 
											WHEN '+' THEN 'C'
											WHEN '-' THEN 'D'
										 END 				 
								,cd.ds_nombre 							AS 'Nombre'   
								,replicate(' ',16)						AS 'Cuenta'
								,convert(BIT,0)							AS 'Contabilizar'
								,cd.bl_noshow 							AS 'noshow'
								,isnull(cd.id_cargo_dep,0) 				AS 'id_cargo_dep'
								,0 										AS 'id_imp_dep'
								,999	 								AS 'C_Orden'
								,0		 								AS 'I_Orden'
								,0		 					AS 'bl_iva'
								,0		 					AS 'bl_iva2'
							FROM dbo.Configuracion_remisiones C 
								INNER JOIN dbo.Clientes_Descuentos CDSC ON CDSC.Id_Configuracion_remisiones = C.Id --And CDSC.id_ConceptoFacturacion IS NOT NULL
								INNER JOIN dbo.CargosDesc CD ON CD.id = CDSC.id_CargosDesc
							WHERE C.Id_Cliente = @Id_Cliente AND (CDSC.id_ConceptoFacturacion = @id_ConceptFac OR CDSC.id_ConceptoFacturacion IS NULL)
							
						/*UNION ALL
						-- Asignacion de por tipo de concepto facturacion
						SELECT  CD.cd_codigo 				AS 'Codigo'
							 	,CD.ds_nombre   			AS 'Concepto'
							 	,convert(NUMERIC(8,4),0)	AS 'Porcentaje'
							 	,'S'						AS 'Editable'
							 	,'N/A'						AS 'Calcular'
							 	,CD.am_valdef    			AS 'Contado'
							 	,convert(money,0)			AS 'Credito'
							 	,CD.am_valdef				AS 'Valor'
								,CD.id 						AS 'id_carg'
								,0							AS 'id_imp'
								,'Tipo'= CASE CD.cd_signo 
											WHEN '+' THEN 'C'
											WHEN '-' THEN 'D'
										 END 				 
								,CD.ds_nombre 				AS 'Nombre'   
								,replicate(' ',16)			AS 'Cuenta'
								,convert(BIT,0)				AS 'Contabilizar'
								,cd.bl_noshow 				AS 'noshow'
								,0 							AS 'id_cargo_dep'
								,0 							AS 'id_imp_dep'																
								,C.in_Orden 				AS 'C_Orden'
								,0		 					AS 'I_Orden'		
								,0		 					AS 'bl_iva'
								,0		 					AS 'bl_iva2'
						FROM dbo.ConceptoFacturacion CF
						INNER JOIN dbo.CargosAsignados C ON C.id_TiposConceptFac = CF.id_TiposConceptoFacturacion
						INNER JOIN dbo.CargosDesc CD ON CD.id = C.id_CargosDesc
						WHERE CF.id = @id_ConceptFac AND CF.bl_contorlarCargImp=0	
						
						UNION ALL
						
						SELECT IR.cd_codigo 										AS 'Codigo'
							 	,IR.ds_alias	   									AS 'Concepto'
							 	,ISNULL(convert(NUMERIC(8,4),IR.am_porcentaje),0)	AS 'Porcentaje'
							 	,'Editable' = CASE IR.bl_editar 
												WHEN 0 THEN 'N'
												WHEN 1 THEN 'S'
									  		  END   
							 	,'Calcular'											AS 'Calcular'
							 	,convert(money,0)									AS 'Contado'
							 	,convert(money,0)									AS 'Credito'
							 	,convert(money,0)									AS 'Valor'
								,C.id_CargosDesc					   				AS 'id_carg'
								,I.id_ImpRet										AS 'id_imp'
								,'Tipo'= CASE IR.cd_tipo 
											WHEN 0 THEN 'I'
											WHEN 1 THEN 'R'
										 END     
								,IR.ds_nombre 						   				AS 'Nombre'   
								,IR.cd_cuenta										AS 'Cuenta'
								,IR.bl_contabilizar									AS 'Contabilizar'
								,convert(BIT,0)										AS 'noshow'
								,isnull(IR.id_cargo_dep,0)                          AS 'id_cargo_dep'
								,isnull(IR.id_imp_dep,0)							AS 'id_imp_dep'
								,C.in_orden											AS 'C_Orden'
								,i.in_Orden		 	   								AS 'I_Orden'
								,bl_iva
								,bl_iva2
						FROM dbo.ConceptoFacturacion CF
						INNER JOIN dbo.CargosAsignados C ON C.id_TiposConceptFac = CF.id_TiposConceptoFacturacion
						INNER JOIN dbo.CargosDesc CD ON CD.id = C.id_CargosDesc
						INNER JOIN dbo.ImpAsignados I ON I.id_CargosAsignados = C.id
						INNER JOIN dbo.ImpRet IR ON IR.id = I.id_ImpRet
						WHERE CF.id = @id_ConceptFac AND CF.bl_contorlarCargImp=0 
						*/
				 	) AS temptbl
				 WHERE Codigo IS NOT NULL 
				 ORDER BY C_Orden, I_Orden ,Id_carg,Id_imp
			END 
			 
			--------------------------------------------------------------------------
						
			RETURN @retval 
	    END TRY 
    
    	-- Bloque CATCH (Manejo de excepciones)
    	BEGIN CATCH 
 		
 			-- Tiempo de espera alcanzado --
		    IF ERROR_NUMBER() = 1222
		    BEGIN
      			SET @msg =  'No se pudo ejecutar el proceso. Tiempo de espera agotado.';
      			SET @retval = 1
	   	        RAISERROR (@msg,16,125);
	   	        RETURN @retval;
		    END
		    
		    -- Registro bloqueado / Conflicto de actualizacion
		    ELSE IF ERROR_NUMBER() IN (1205, 3960)
    		BEGIN  	        
		       	SET @retry     = 1              ;
		       	SET @retrycont = @retrycont + 1 ; 
	    	 END
	    	 ELSE
		     BEGIN
		     	-- Error no manejado --


					SET @retval = 1;
  	 				SET @msg =	'Ha ocurrido un error. Información para soporte tecnico:'			+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							    'Numero: ' + isnull(CAST(ERROR_NUMBER()   AS VARCHAR(10)),'') 		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
								'Mensaje: ' + isnull(ERROR_MESSAGE(),'') 					   		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							 	'Severidad: ' + isnull(CAST(ERROR_SEVERITY() AS VARCHAR(10)),'') 	+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							 	'Estado: ' + isnull(CAST(ERROR_STATE()    AS VARCHAR(10)),'') 		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
								'Procedimiento: ' + isnull(ERROR_PROCEDURE(),'')					+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
								'Linea: ' + isnull(CAST(ERROR_LINE() 	   AS VARCHAR(10)),''); 							
		
					RAISERROR (@msg,16,126);
					--Se debe auditar proceso fallido
					/*IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar	@id_proceso = @idproce   ,
											 			 			@id_usuario = @id_usuario ,
											 			 			@cd_status  = 0           , 
											 			 			@admsg      = @msg	  ;*/				
					RETURN @retval;
		     END
		END CATCH     
	END 
	
	IF (@retrycont>@maxretries) 
	BEGIN 
		SET @retval = 1
		SET @msg = 'No se pudo finalizar el proceso. Maximo numero de reintentos alcanzado.'
		--Se debe auditar proceso fallido
		/*IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
											 			 @id_usuario = @id_usuario ,
											 			 @cd_status  = 0           , 
											 			 @admsg      = @msg	   ;*/												 	   					   
  		RAISERROR (@msg,16,127);
  		RETURN @retval;
  	END   	
    
    RETURN @retval;
END


GO

--liquibase formatted sql
--changeset jtorres:1 dbms:mssql runOnChange:true stripComments:false endDelimiter:GO
If Exists ( Select Name From sys.objects Where object_id = OBJECT_ID( N'[dbo].[spza_ConfiguracionVariablesJOB_ObtenerValores]' ) And OBJECTPROPERTY( object_id , N'IsProcedure' ) = 1 )
	DROP PROCEDURE dbo.spza_ConfiguracionVariablesJOB_ObtenerValores
GO

CREATE PROCEDURE [dbo].[spza_ConfiguracionVariablesJOB_ObtenerValores] 
	-- Parametros del procedimiento
	@id_usuario 	INT,
	@id_Reservas	VARCHAR(8000)=NULL,
	@cd_Reservas    Varchar(25)=NULL,
	@id_ReservaGDS_Detalles INT=NULL, --rgelis 2018/10/26 req.62804
	@id_ReservaGDS_Servicios INT=NULL --rgelis 2018/10/26 req.62804
	

WITH Encryption	
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
			@retval		TINYINT 		, -- Valor de retorno de este procedimiento: 0:Exito ; 1:Error(Bloque Catch)
			@Id_DQB_Conciliacion INT	;

	SELECT 	@idproce 			 = 210,
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
				SELECT 'No posee permisos suficientes para ejecutar esta acción.' AS 'Respuesta'
				RETURN @retval;
			END 
			
			--Instrucciones del procedimiento-----------------------------------------


			DECLARE 
				@GDS 				VARCHAR(MAX)
				, @NumVariables 	INT 
				, @Iden_GDS			INT 
				, @Contador			INT 
				, @Fila 			VARCHAR(MAX)
				--Informacion de las variables
				, @id_Reserva       INT
				, @Iden_Variable    NUMERIC (18)
				, @ds_Linea         VARCHAR (20)
				, @ds_campo         VARCHAR (20)
				, @in_tipo_longitud INT
				, @in_posinicial    INT
				, @in_longitud      INT
				, @ValorObtenido	 VARCHAR(MAX)
				, @PNR				VARCHAR(12)	
				, @IDEN_Maestro		INT --rgelis 2018/10/26 req.62804
				, @NumVariablesFomuladas INT
				, @Formula			VARCHAR(MAX)
				, @FormulaAux		VARCHAR(MAX)

			 
			DECLARE @Tabla TABLE(id_Reserva INT,GDS VARCHAR(MAX),Iden_GDS INT) --rgelis 2017/03/16 req.48076
			DECLARE @TVariablesFormula AS TABLE(id INT IDENTITY,Iden_variable NUMERIC(18),cd_variable VARCHAR(max))
			IF ISNULL(@cd_Reservas,'') <> ''
			BEGIN
				INSERT INTO @Tabla(id_Reserva,GDS,Iden_GDS) --rgelis 2017/03/16 req.48076
				SELECT r.id AS id_Reserva, r.reserva AS  GDS , r.iden_gds  
				FROM dbo.ReservasGDS r WHERE r.cd_codigo = @cd_Reservas
				  
				--SET @PNR = @cd_Reservas --rgelis 2017/03/16 req.48076
			END
			ELSE
			BEGIN 
				INSERT INTO @Tabla(id_Reserva,GDS,Iden_GDS) --rgelis 2017/03/16 req.48076
				SELECT r.id AS id_Reserva, r.reserva AS  GDS , r.iden_gds
				FROM dbo.ReservasGDS r
				INNER JOIN dbo.fnSplitMejorado(@id_Reservas,',',0,1) AS s ON CONVERT(INT,s.Codigo) = r.id
			
				--SELECT @PNR = cd_codigo --rgelis 2017/03/16 req.48076
				--FROM dbo.ReservasGDS
				--WHERE Id IN (SELECT id_Reserva FROM @Tabla)	
			END  

			DECLARE @TVariables TABLE 
							(
							Id               INT IDENTITY NOT NULL,
							Id_Reserva		 INT NOT NULL, --rgelis 2017/03/16 req.48076
							IDEN_Maestro	 NUMERIC (18) NOT NULL,	--rgelis 2017/03/16 req.48076
							Iden_Variable    NUMERIC (18) NOT NULL,
							ds_Linea         VARCHAR (20),
							ds_campo         VARCHAR (20) NOT NULL,
							in_tipo_longitud INT NOT NULL,
							in_posinicial    INT NOT NULL,
							in_longitud      INT NOT NULL,
							ValorObtenido	 VARCHAR(MAX),
							Formula			 VARCHAR(MAX)
							)
				
			--Obtenemos la informacion de la reserva
			--SELECT  --rgelis 2017/03/16 req.48076
			--	@GDS = Reserva 
			--	,@Iden_GDS = iden_gds
			--FROM dbo.ReservasGDS 
			--WHERE cd_codigo=@PNR

			IF @id_ReservaGDS_Detalles = 0 --rgelis 2018/10/26 req.62804
				SET @id_ReservaGDS_Detalles =  NULL
			
			IF @id_ReservaGDS_Servicios = 0
				SET @id_ReservaGDS_Servicios =  NULL --rgelis 2018/10/26 req.62804

			IF @id_ReservaGDS_Detalles IS NULL AND @id_ReservaGDS_Servicios IS NULL --rgelis 2018/10/26 req.62804
			BEGIN 
				--Insetamos la reserva por filas en una tabla temporal
				Declare @TableReserva AS TABLE(id INT IDENTITY,Fila VARCHAR(max),id_reserva INT) --inicio rgelis 2017/03/16 req.48076
				INSERT INTO @TableReserva(Fila,id_reserva) 
				SELECT REPLACE(REPLACE(f.Codigo,CHAR(10),''),CHAR(13),'')  AS Fila,r.id_Reserva 
				FROM @Tabla r
				OUTER APPLY dbo.fnSplitMejorado(r.GDS,CHAR(13)+CHAR(10),0,0) AS f --rgelis 2017/05/10 req.....
				ORDER BY r.id_Reserva,f.id  --fin rgelis 2017/03/16 req.48076

				
				--UPDATE @TableReserva
				--SET FILA = REPLACE(REPLACE(filA,CHAR(10),''),CHAR(13),'')

				--Obtenemos la informacion de las variables parametrizadas para el GDS de la reserva
				INSERT INTO @TVariables (Id_Reserva,IDEN_Maestro,Iden_Variable,ds_Linea,ds_campo,in_tipo_longitud,in_posinicial,in_longitud,Formula) --inicio rgelis 2017/03/16 req.48076
				SELECT r.id_Reserva,c.IDEN_Maestro,c.Iden_Variable,c.ds_Linea,c.ds_campo,c.in_tipo_longitud,c.in_posinicial,c.in_longitud,v.FormulaDefault AS 'Formula' 
				FROM @Tabla r 
				INNER JOIN dbo.ConfiguracionVariables c ON (r.Iden_GDS = c.Iden_GDS OR c.Iden_GDS = 0)
				INNER JOIN dbo.VariableDefinicion v ON v.IDEN = c.Iden_Variable
				GROUP BY r.id_Reserva,c.IDEN_Maestro,c.Iden_Variable,c.ds_Linea,c.ds_campo,c.in_tipo_longitud,c.in_posinicial,c.in_longitud,v.FormulaDefault --fin rgelis 2017/03/16 req.48076  

				SET @NumVariables = @@ROWCOUNT
				/*declare @comodin char(1)*/ --Solo FROSCH
				--select * from @TVariables
				--Inicializamos variables
				SET @Contador = 1
				--Ciclo para obtener la informacion de las varibles
				WHILE @Contador <= @NumVariables
				BEGIN 
	
					SELECT 
						@ds_Linea = RTRIM(ds_Linea)  --rgelis 2020/01/07 ticket.110744
						, @ds_campo = RTRIM(ds_campo) --rgelis 2020/01/07 ticket.110744
						, @in_tipo_longitud = in_tipo_longitud
						, @in_posinicial = in_posinicial
						, @in_longitud = in_longitud
						, @Id_Reserva = Id_Reserva --rgelis 2017/03/16 req.48076
					FROM @TVariables WHERE Id = @Contador
					/*SET @Comodin = Case When right(@ds_campo,1) NOT IN ('*','-','/') THEN space(1) Else '' END*/ --Solo FROSCH
					/*SELECT @Fila = Fila FROM @TableReserva WHERE Fila LIKE (@ds_Linea+'%') AND Fila LIKE ('%'+@ds_campo+@comodin+'%') AND id_reserva = @Id_Reserva --fin rgelis 2017/03/16 req.48076*/--Solo FROSCH
					SELECT @Fila = Fila FROM @TableReserva WHERE Fila LIKE (@ds_Linea+'%') AND Fila LIKE ('%'+@ds_campo+'%') AND id_reserva = @Id_Reserva --fin rgelis 2017/03/16 req.48076
					SELECT @ValorObtenido = substring(@Fila,charindex(@ds_campo,@Fila,0)+len(@ds_campo),len(@Fila))
				
					--Debug
					--SELECT 
					--	@ds_Linea AS '@ds_Linea', @ds_campo AS '@ds_campo', @in_tipo_longitud AS '@in_tipo_longitud', @in_posinicial AS '@in_posinicial', @in_longitud AS '@in_longitud'
					--	, @Fila AS '@Fila', @ValorObtenido AS '@ValorObtenido'

					--Si es longitud fija,obtenemos la informacion segun la configuracion de la variables
					IF @in_tipo_longitud = 0
					BEGIN
						SET @ValorObtenido = substring(@ValorObtenido,@in_posinicial,@in_longitud)
					END 
	
					UPDATE @TVariables
					SET ValorObtenido = @ValorObtenido
					WHERE Id = @Contador	
		
					SET @Contador = @Contador + 1
					SELECT @Fila = ''
				END 
			END
			ELSE IF @id_ReservaGDS_Detalles IS NOT NULL 
			BEGIN
				SELECT @IDEN_Maestro = IDEN FROM dbo.VariableDefinicionMaestro WHERE Codigo = 'Tiquetes' 
				INSERT INTO @TVariables (Id_Reserva,IDEN_Maestro,Iden_Variable,ds_Linea,ds_campo,in_tipo_longitud,in_posinicial,in_longitud,ValorObtenido,Formula) 
				SELECT r.id_Reserva, @IDEN_Maestro AS 'IDEN_Maestro', VD.IDEN AS 'Iden_Variable', '' AS 'ds_Linea', r.ds_nombre AS ds_campo, 0 AS 'in_tipo_longitud', 0 AS 'in_posinicial', 0 AS 'in_longitud', r.ds_valor AS 'ValorObtenido', VD.FormulaDefault AS 'Formula'
				FROM dbo.ReservaGDS_VariableAdicional r
				INNER JOIN @Tabla t ON t.id_Reserva = r.id_reserva 
				INNER JOIN VariableDefinicion VD ON VD.Nombre = r.ds_nombre
				WHERE r.id_ReservaGDS_Detalles = @id_ReservaGDS_Detalles
					AND VD.IDEN_TipoVariable = 2
			END
			ELSE IF @id_ReservaGDS_Servicios IS NOT NULL 
			BEGIN
				SELECT @IDEN_Maestro = IDEN FROM dbo.VariableDefinicionMaestro WHERE Codigo = 'FacturacionServicios' 
				INSERT INTO @TVariables (Id_Reserva,IDEN_Maestro,Iden_Variable,ds_Linea,ds_campo,in_tipo_longitud,in_posinicial,in_longitud,ValorObtenido,Formula) 
				SELECT r.id_Reserva, @IDEN_Maestro AS 'IDEN_Maestro', VD.IDEN AS 'Iden_Variable', '' AS 'ds_Linea', r.ds_nombre AS ds_campo, 0 AS 'in_tipo_longitud', 0 AS 'in_posinicial', 0 AS 'in_longitud', r.ds_valor AS 'ValorObtenido',VD.FormulaDefault AS 'Formula'
				FROM dbo.ReservaGDS_VariableAdicional r
				INNER JOIN @Tabla t ON t.id_Reserva = r.id_reserva 
				INNER JOIN VariableDefinicion VD ON VD.Nombre = r.ds_nombre
				WHERE r.id_ReservaGDS_Servicios = @id_ReservaGDS_Servicios
					AND VD.IDEN_TipoVariable = 2
				
			END

			SELECT @NumVariables = Count(*) FROM @TVariables 
			SELECT @NumVariablesFomuladas = Count(*) FROM @TVariables WHERE ISNULL(Formula,'')<>'' 
			SET @Contador = 1
			--Ciclo para obtener la informacion de las varibles formuladas
			IF (ISNULL(@NumVariablesFomuladas,0)>0)
			BEGIN
				WHILE @Contador <= @NumVariables
				BEGIN
					SELECT 
						@ds_Linea = RTRIM(ds_Linea)  
						, @ds_campo = RTRIM(ds_campo) 
						, @in_tipo_longitud = in_tipo_longitud
						, @in_posinicial = in_posinicial
						, @in_longitud = in_longitud
						, @Id_Reserva = Id_Reserva 
						, @Formula = RTRIM(Formula)
					FROM @TVariables WHERE Id = @Contador AND ISNULL(Formula,'')<>''

					IF ISNULL(@Formula,'')<>''
					BEGIN
						SET @FormulaAux= REPLACE(REPLACE(REPLACE(REPLACE(@Formula,'Z!VAR_',''),'!',''),'&',','),'+',',')
					
						DELETE FROM @TVariablesFormula
					
						INSERT INTO @TVariablesFormula(Iden_Variable,cd_variable)
						SELECT Iden_Variable=IDEN ,cd_variable=Codigo 
						FROM dbo.fnSplitMejorado(@FormulaAux,',',0,1) ve
						INNER JOIN dbo.VariableDefinicion v ON v.Nombre = ve.Codigo AND v.TipoVariable='Documento'
					
						SET @ValorObtenido=@Formula
						SELECT @ValorObtenido=REPLACE(REPLACE(REPLACE(@ValorObtenido,'Z!VAR_'+cd_variable+'!',ValorObtenido),'&',''),'+','') 
						FROM @TVariables v
						INNER JOIN @TVariablesFormula vf ON vf.Iden_variable = v.Iden_Variable  
					
						UPDATE @TVariables
						SET ValorObtenido = @ValorObtenido
						WHERE Id = @Contador AND ISNULL(Formula,'')<>''
					END
				END
			END

			SELECT DISTINCT
				TV.Iden_Variable
	  			,VD.Nombre
	  			,TV.ValorObtenido
				,TV.Id_Reserva --inicio rgelis 2017/03/16 req.48076
				,TV.IDEN_Maestro 
				,VDM.Codigo AS cd_Maestro --fin rgelis 2017/03/16 req.48076 
			FROM @TVariables TV
			INNER JOIN VariableDefinicion VD ON VD.Iden = TV.Iden_Variable
			INNER JOIN VariableDefinicionMaestro VDM ON VDM.IDEN = TV.IDEN_Maestro --rgelis 2017/03/16 req.48076     
			--WHERE ISNULL(ValorObtenido,'') <> '' --rgelis 2017/03/15 req..... correcion para que traiga todas las variables configuradas
			
			IF (@@ROWCOUNT<1)
				SET @msg = 'Consulta Fallida';
							
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
			--SELECT ltrim(rtrim(@msg)) AS 'Respuesta';			
			RETURN @retval;
	    END TRY 
    
    	-- Bloque CATCH (Manejo de excepciones)
    	BEGIN CATCH 
 			
 			-- Tiempo de espera alcanzado --
			IF ERROR_NUMBER() = 1222
			BEGIN
      			SET @msg =  'No se pudo ejecutar el proceso. Tiempo de espera agotado.';
      			SET @retval = 1
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
		       	SET @retry     = 1              ;
		       	SET @retrycont = @retrycont + 1 ; 

	    	END
	    	ELSE
		    BEGIN
				-- Error no manejado --
				--IF (XACT_STATE() <> 0)
	   	        BEGIN 				
					SET @retval = 1;
  	 				SET @msg =	'Ha ocurrido un error. Información para soporte tecnico:'			+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
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


GO

IF OBJECT_ID('dbo.spza_FacturaJOB_Crear', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spza_FacturaJOB_Crear;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE [dbo].[spza_FacturaJOB_Crear]
	-- Parametros del procedimiento		
	@id_usuario						INT,  
	@id_sucursal					INT, 
	@id_implante					INT, 
	@dt_fechacont					SMALLDATETIME,
	@dt_vence						SMALLDATETIME ,
	@cd_tercero_codigo				VARCHAR(25) ,
	@ds_tercero_nombre				VARCHAR(250),
	@cd_cliente_codigo				VARCHAR(25), --rgelis 2017/02/23 req.47387
	@ds_cliente_nombre				VARCHAR(250),
	@ds_cliente_dir					VARCHAR(250),
	@ds_cliente_ciudad				VARCHAR(40),
	@ds_cliente_tel					VARCHAR(50),
	@ds_cliente_dirdesp				VARCHAR(250),
	@ds_cliente_email				VARCHAR(60),
	@ds_cliente_contacto			VARCHAR(40),
	@ds_cliente_contacto_email		VARCHAR(60),
	@id_monedas_iata				INT,
	@cd_vendedor					CHAR(3),
	@id_tiqueteador					INT,
	@bn_anexo						VARBINARY = NULL ,
	@Tcambio						MONEY = 1,
	@am_tcambiousd					MONEY = 1,
	@id_tipoventa					INT,
	@ds_num_resolucion				VARCHAR(20), 
	@in_num_inicial					NUMERIC(18,0), 
	@in_num_final					NUMERIC(18,0), 
	@ds_numeracion_autorizada		VARCHAR(50),
	@dt_fecha_resolucion			SMALLDATETIME,	
	@CodigoArchivoFisico			VARCHAR(25),
	@ds_Observacion					VARCHAR(8000) ,
	@ds_Campo_libre1				varchar(500),
	@ds_Campo_libre2				varchar(500),
	@cd_fuente_Reemplaza			CHAR(2),
	@cd_serie_Reemplaza				CHAR(2),
	@cd_consecutivo_Reemplaza		CHAR(8),		
	@ds_Actividad_Economica			VARCHAR(10),
	@ds_Tarifa_ICA					VARCHAR(15),	
	@SqlStmt						NVARCHAR(max),
	@AnticiposSqlStmt				NVARCHAR(max)=NULL,
	@TotalFactura					MONEY = 0,
	@TotalCupoCreditoCliente		MONEY = 0,
	@bl_BloqueoCupoCredito			BIT = 0,
	@bl_generadaauto				BIT = 0,
	@ds_CotizacionesId				Varchar(500)= NULL,
	@Id_Cierre						INT = NULL,
	@cd_TipoFact					CHAR(2)= NULL, /*rgelis 2012/10/31 req.10779*/
	@id_fac_remisionRelacionada		INT= NULL, /*rgelis 2013/12/23*/
	@id_fac_facturaRelacionada		INT= NULL, /*rgelis 2013/12/23*/
	@ds_DescripcionFac				VARCHAR(500)=NULL, /*rgelis 2014/02/25 req.18557*/
	@bl_nocont						BIT = 0, --rgelis 2018/04/30 req.33683
	@ProductosSqlStmt				NVARCHAR(max)=NULL,
	@cd_CF_TipoComprobante			VARCHAR(15)=NULL,
	@id_Licitacion					INT   =NULL ,
	@ValorFactura					MONEY = 0	,
	@id_Especialista				INT  =NULL,
	@id_tiqueteador_Facturador		INT = NULL,
	@id_TipoFormaPagoProveedor		INT = NULL,
	@id_MedioReservacion			INT = NULL,
	@bl_refacturacion				BIT = 0,
	@bl_comisiona					BIT = 0,
	@cd_fuente_factura				VARCHAR(2)= NULL,
	@cd_serie_factura				VARCHAR(2)= NULL,
	@cd_consecutivo_factura			VARCHAR(8)= NULL,
	@id_NotasAerolinea				INT=NULL,
	@bl_interface					INT = 0,
	@id_evento						INT   =NULL ,
	@bl_NoEnviarFacElectronica		BIT = 0,
	--@bl_FacturaComision			BIT = 0, --JARG - Req.30454 2016/03/16 - Descontar comision de la CxP de la factura Original
	@bl_DescontarComisionCxP		BIT = 0,	 --JARG - Req.30454 2016/03/16 - Descontar comision de la CxP de la factura Original
	@ds_num_resolucion_Adicional	VARCHAR(20) = '',
	@id_fac_facturaRefacturacion	VARCHAR(8000) = NULL,
	@bl_refacturacion_contabilizar_saldos BIT = 0,
	@ZML_VariablesXML				VARCHAR(MAX) = NULL,--rgelis 2017/01/04 req.46086
	@bl_FormatoResumidoFactElectro	BIT= 0, --rgelis 2018/10/08 Req.63202
	@bl_ExigeAdjuntoFactElectro		BIT= 0, --rgelis 2019/07/25 req.90259
	@bl_omitir_Validar_IVA_facturacion BIT = 0,
	@ZML_AjusteIvaXML				VARCHAR(MAX) = NULL,
	@ds_RespuestaJOB				VARCHAR(MAX) = NULL OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON: Previene que conjuntos de resultados extras interfieran con 
	-- expresiones SELECT
	SET NOCOUNT ON;

    -- Declaracion e inicializacion de variables
  	DECLARE @bl_permit				BIT 	, -- Permiso de ejecucion del proceso
  			@bl_as 	   				BIT	, -- Auditar exito
	 		@bl_af 					BIT	, -- Auditar fallido	 		
			@procmsg				VARCHAR(8000)	, -- Mensaje devuelto por procedimientos llamados desde este procedimiento
			@Resolucionmsg			VARCHAR(8000)	, -- Mensaje devuelto por procedimientos llamados desde este procedimiento
			@procret 				BIT 			, -- Valor de retorno de los procedimientos llamados desde este procedimiento
			@idproce				int		    	, -- Codigo de proceso
	 		@retry 					BIT			    , -- 1=Reintentar ; 0=Abortar  
	 		@retrycont				INT			    , -- Contador de reintentos
	 		@maxretries 			INT			    , -- Maximo numero de reintentos
	 		@timeout				NVARCHAR(4000)  , -- Tiempo de espera maximo por bloqueo de registros
	 		@stmt 					NVARCHAR(4000)  , -- Cadena de instrucciones T-SQL
			@msg	    			VARCHAR(8000)   , -- Mensaje retornado por el sistema
			@retval					TINYINT 		, -- Valor de retorno de este procedimiento: 0:Exito ; 1:Error(Bloque Catch)
			@cd_serieRC				CHAR(2)			, -- Recibo de caja automatico
			@cd_fuenteRC			CHAR(2)			, -- Recibo de caja automatico
			@cd_consecutivoRC		CHAR(8)			, -- Recibo de caja automatico	
			@cd_serieRCOtr			CHAR(2)			, -- Recibo de caja automatico
			@cd_fuenteRCOtr			CHAR(2)			, -- Recibo de caja automatico
			@cd_consecutivoRCOtr	CHAR(8)			, -- Recibo de caja automatico	
			@NCF					varchar(25)		,
			@FechaCaducidad 		SmallDateTime	,
			@DocumentoCont			Varchar(10)		,
			@Id_SucursalFullFilment INT				,
			@bl_usarimplanteFullFilment INT			, 
			@Id_implanteFullFilment INT				,
			@Id_SucursalResolucion INT				,
			@Id_implanteResolucion INT				,
			@FacturadorElect varchar(50)			;

	SELECT 	@idproce 			 = 93,
			@retry				 = 1,
			@retrycont			 = 0,
			@retval				 = 0;
  	
  	-- Manejo de tiempo de espera y de reintentos por bloqueo de tablas/registros  
   	SELECT @maxretries = convert(INT,Valor) FROM dbo.Parametros WHERE Id = 60 ;
	SELECT @timeout    = convert(NVARCHAR(4000),Valor) FROM dbo.Parametros WHERE Id = 50 ;		
	SET @stmt = N'SET LOCK_TIMEOUT '+ltrim(rtrim(@timeout))
	EXEC sp_executesql @stmt,N''
	
	
	WHILE ((@retry = 1) AND (@retrycont <= @maxretries) )
	BEGIN
		SET @retry = 0;
    
    	-- Bloque TRY
    	BEGIN TRY 

			IF (NOT EXISTS(SELECT id FROM Usuario WHERE Id = @id_usuario) AND ISNULL(@Id_Cierre,0)<>0)
			BEGIN
				SELECT @id_usuario=id_usuario FROM dbo.Cierres WHERE id = @Id_Cierre  
			END
    	    		
    		--Obteniendo informacion de seguridad y auditoria--
			EXEC dbo.spzaProcesoUsuario_Consultar @id_usuario   = @id_usuario       ,
												  @id_proceso   = @idproce 		    , 
												  @bl_permit    = @bl_permit OUTPUT , 
												  @bl_auditsuc  = @bl_as 	 OUTPUT , 
												  @bl_auditfail = @bl_af 	 OUTPUT ;
			IF (@bl_permit = 0)
			BEGIN 
				SET @ds_RespuestaJOB = 'No posee permisos suficientes para ejecutar esta acciÃ³n.';SET @ds_RespuestaJOB = 'No posee permisos suficientes para ejecutar esta acciÃ³n.';
				RETURN @retval;
			END 
			
			IF @id_implante = 0
				SET @id_implante = NULL;

			IF NOT EXISTS(SELECT * FROM dbo.Implantes WHERE Implantes.id = @id_implante and Implantes.id_sucursal = @id_sucursal) AND @id_implante IS NOT NULL
			BEGIN
				SET @procmsg = 'El Implante ingresado en la Factura no esta asociado a la sucursal, verifique la configuracion implante - sucursal'
				SET @ds_RespuestaJOB = @procmsg;
				SET @ds_RespuestaJOB = @procmsg;
				RETURN 1 ;
			END	
			
			IF (RTRIM(ISNULL(@cd_vendedor,'')) = '')
			BEGIN 
				SET @ds_RespuestaJOB = 'No ingreso el vendedor de la factura por favor verificar.';SET @ds_RespuestaJOB = 'No ingreso el vendedor de la factura por favor verificar.';
				RETURN @retval;
			END
					 
			--Jramirez - 20180413 - Ticket #17146
			DECLARE @in_dias_vence INT , @ds_msj_rpta VARCHAR(8000)
			--IF EXISTS(Select * From Configuracion_remisiones Where id_cliente=@cd_cliente_codigo AND bl_BloqDiaVence = 1 AND in_dias_vence>=1)
			--BEGIN 
			--	Select @in_dias_vence = in_dias_vence From Configuracion_remisiones Where id_cliente=@cd_cliente_codigo AND bl_BloqDiaVence = 1 AND in_dias_vence>=1
			--	EXEC [spza_Configuracion_remisiones_ConsultarBloqVence]
			--		@id_usuario 		=1			,
			--		@id_cliente  		 = @cd_cliente_codigo,
			--		@in_dias_vence  	= @in_dias_vence,
			--		@bl_devolverMSJ		= 1,
			--		@ds_msj_rpta		= @ds_msj_rpta OUTPUT
			--		IF @ds_msj_rpta <> ''
			--		BEGIN
			--			SET @ds_RespuestaJOB = @cd_cliente_codigo;
			--			RETURN 1 ;
			--		END 
			--END 

			--Iniciando / salvando transaccion dependiendo si ya esta iniciada o no--
		  	BEGIN TRAN;
			
			--Verificamos si tiene sucursal por Full Filment, es decir toma la inf de facturacion de otra sucursal
			SELECT @Id_SucursalFullFilment = sff.Id
			FROM dbo.Sucursales s
			INNER JOIN dbo.Sucursales sff ON sff.id = s.Id_SucursalFullFilment
			WHERE s.id = @id_sucursal and s.bl_usarsucursalFullFilment = 1

			SELECT @Id_implanteFullFilment = iff.id 
			FROM dbo.Implantes i
			INNER JOIN Implantes iff ON iff.id = i.Id_implanteFullFilment
			WHERE i.id=@id_implante 

			--Instrucciones del procedimiento-----------------------------------------
			SET @procmsg = ''  	
			SET @Resolucionmsg = ''		
			DECLARE @cd_serie CHAR(2);
			DECLARE @cd_fuente CHAR(2);
			DECLARE @cd_consecutivo CHAR(8);
			DECLARE @in_ConsecutivoUnicoDocumento INT; --jramirez - 2017/12/05 - Manejo de consecutivo unico
			DECLARE @id_ConsecutivoUnicoDocumento INT; --jramirez - 2017/12/05 - Manejo de consecutivo unico
			DECLARE @id_Contingencia INT;
			Declare @DocumentoCausacionCxP Varchar(15)  --jramirez -- Causacion CxP servicio de terceros
					
			IF @cd_fuente_factura <> '' AND @cd_serie_factura <> '' AND @cd_consecutivo_factura <> '' 
			BEGIN 
				IF EXISTS(SELECT * FROM dbo.fac_factura WHERE fac_factura.cd_fuente = @cd_fuente_factura and fac_factura.cd_serie = @cd_serie_factura AND fac_factura.cd_consecutivo = @cd_consecutivo_factura)
				BEGIN 
					SET @procmsg = 'El Numero de Factura ingresado ya se encuentra en uso'
				END 
				ELSE
				BEGIN
					SELECT @cd_fuente		= @cd_fuente_factura,
						   @cd_serie		= @cd_serie_factura,
						   @cd_consecutivo	= @cd_consecutivo_factura
				END 
			END
			ELSE 
			BEGIN
				
				IF @Id_SucursalFullFilment IS NOT NULL
				BEGIN 
					EXEC @procret = dbo.spza_IncrementaConsecutivo @id_MaeTipoTransacciones			= 2,
													   			@id_sucursal						= @Id_SucursalFullFilment,
													   			@id_implante						= NULL, 
													   			@cd_fuente							= @cd_fuente OUTPUT,
													   			@cd_serie							= @cd_serie	OUTPUT,
													   			@cd_consecutivo						= @cd_consecutivo OUTPUT,
													   			@errmsg								= @procmsg OUTPUT, 
													   			@msg								= @Resolucionmsg OUTPUT,
																@ds_num_resolucion_Adicional		= @ds_num_resolucion_Adicional,
																@in_ConsecutivoUnicoDocumento		= @in_ConsecutivoUnicoDocumento OUTPUT,
																@id_ConsecutivoUnicoDocumento		= @id_ConsecutivoUnicoDocumento OUTPUT,
																@id_Contingencia					= @id_Contingencia OUTPUT;
				END
				ELSE IF @Id_implanteFullFilment IS NOT NULL 
				BEGIN 
					EXEC @procret = dbo.spza_IncrementaConsecutivo @id_MaeTipoTransacciones = 2,
													   			@id_sucursal             = @id_sucursal    ,
													   			@id_implante             = @Id_implanteFullFilment    , 
													   			@cd_fuente               = @cd_fuente     OUTPUT ,
													   			@cd_serie				 = @cd_serie     OUTPUT ,
													   			@cd_consecutivo          = @cd_consecutivo OUTPUT ,
													   			@errmsg					 = @procmsg OUTPUT, 
													   			@msg					 = @Resolucionmsg OUTPUT,
																@ds_num_resolucion_Adicional = @ds_num_resolucion_Adicional,
																@in_ConsecutivoUnicoDocumento		=@in_ConsecutivoUnicoDocumento OUTPUT,
																@id_ConsecutivoUnicoDocumento		= @id_ConsecutivoUnicoDocumento OUTPUT,
																@id_Contingencia					= @id_Contingencia OUTPUT;
				END 
				ELSE 
				BEGIN 
					EXEC @procret = dbo.spza_IncrementaConsecutivo @id_MaeTipoTransacciones = 2,
													   			@id_sucursal             = @id_sucursal    ,
													   			@id_implante             = @id_implante    , 
													   			@cd_fuente               = @cd_fuente     OUTPUT ,
													   			@cd_serie				 = @cd_serie     OUTPUT ,
													   			@cd_consecutivo          = @cd_consecutivo OUTPUT ,
													   			@errmsg					 = @procmsg OUTPUT, 
													   			@msg					 = @Resolucionmsg OUTPUT,
																@ds_num_resolucion_Adicional = @ds_num_resolucion_Adicional,
																@in_ConsecutivoUnicoDocumento		=@in_ConsecutivoUnicoDocumento OUTPUT,
																@id_ConsecutivoUnicoDocumento		= @id_ConsecutivoUnicoDocumento OUTPUT,
																@id_Contingencia					= @id_Contingencia OUTPUT;
				END
			END 	
			IF NOT @procmsg <> ''
			AND EXISTS(SELECT * FROM dbo.fac_factura WHERE fac_factura.cd_fuente = @cd_fuente and fac_factura.cd_serie = @cd_serie AND fac_factura.cd_consecutivo = @cd_consecutivo)
			BEGIN 
				SET @procmsg = 'El Numero de Factura: ' + @cd_fuente + '-' + @cd_serie + @cd_consecutivo + ' ya se encuentra en uso'
			END 


																					   	
			IF (@procmsg <> '') -- Proceso de incremento de consecutivo fallido				
			BEGIN 
				IF @@TRANCOUNT > 0 
				BEGIN 
					ROLLBACK TRAN;	
				END 
				
				IF (@bl_af = 1) --Se debe auditar proceso fallido
				BEGIN 						
				EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
												 @id_usuario = @id_usuario ,
												 @cd_status  = 1           , 												 
												 @admsg      = @procmsg	   ;	 
				END 		  
				

			    IF @bl_generadaauto=1
				BEGIN
					SET @ds_RespuestaJOB = @procmsg;
				END 
				ELSE
				BEGIN
					SET @ds_RespuestaJOB = @procmsg;
				END
				
				SET @ds_RespuestaJOB = @procmsg + ' '+  ISNULL(@Resolucionmsg,'') +' SUCURSAL:' + CONVERT(VARCHAR(3),ISNULL(@id_sucursal,0))+' IMPLANTE:' + CONVERT(VARCHAR(3),ISNULL(@id_implante,0));
				RETURN 1 ;

			END 

			--Comprobante fiscal
			If  Exists(Select* from parametros where Id=232 and valor='S') 
			And 
			Not Exists(Select * from clientes where IndNCF=1 And idcliente=@cd_cliente_codigo)
			Begin
				 
				Declare @ErrorNCF		Int
				Declare @LoginUsuario	Varchar(250) /*rgelis 2016/11/29 req.34692*/
				Declare @BU				Varchar(25)
				
				Select 
					@ErrorNCF	=	0,
					@LoginUsuario	=	Isnull(Login,''),
					@BU		=	CASE 
									WHEN i.id IS NOT NULL AND Isnull(i.cd_bu,'') <> '' THEN i.cd_bu
									WHEN s.id IS NOT NULL AND Isnull(s.cd_bu,'') <> '' THEN i.cd_bu
									ELSE '' 
								END 
				From dbo.Usuario u
				Inner Join dbo.Sucursales s ON s.id = u.id_sucursal
				Left  Join dbo.Implantes i ON i.id = u.id_implante
				Where u.Id=@id_usuario
				

				/*JARG - 2014/10/10 - Req.22484
				  Esto se hace para republica dominicana por que se necesita generar el NCF dependiendo del tipo de identificacion 
				  del cliente y agencias no permite mandar varias series, entonces se pone la serie en el codigo alterno del tipo 
				  de identificacion.*/
				DECLARE @cd_serie_NCF VARCHAR(2)
				SET @cd_serie_NCF = @cd_serie
				IF EXISTS(SELECT * FROM dbo.Parametros WHERE Parametros.Id = 240 AND Parametros.Valor = 'RepÃºblica Dominicana')
				BEGIN
					SELECT @cd_serie_NCF = @cd_CF_TipoComprobante
				END 

				Exec @ErrorNCF = spCF_Configuracion
						@Op='Consecutivo',
						@Fuente=@cd_fuente,
						@Series=@Cd_serie_NCF,
						@Usuario=@LoginUsuario,
						@BU=@Bu,
						@AplicacionUsuario='Agencia Minorista SQL',
						@NoFiscal=@NCF Output,
						@FechaCaducidad = @FechaCaducidad OutPut,
						@FechaDocumento = @dt_fechacont
				

				--Parche Comprobante fiscal: NCF es igual al numero de la factura.
				If  Exists(Select* from parametros where Id=431 and valor='S') 
				BEGIN
					SET @NCF = LEFT(@NCF,7)+@CD_CONSECUTIVO

					UPDATE DC 
					SET DC.NCF=FF.NCF
					FROM CF_DOCUMENTOCONTROL DC
					INNER JOIN FAC_FACTURA FF ON FF.CD_FUENTE = DC.FUENTE AND  FF.NUMERO = DC.DOCUMENTO
					WHERE DC.FUENTE = @cd_fuente AND DC.DOCUMENTO = @cd_serie + @cd_consecutivo AND DC.NCF<>FF.NCF
				END 

				IF (@ErrorNCF <> 0 Or @@Error <> 0) -- Proceso de incremento de consecutivo fallido				
				BEGIN 
					Set @procmsg = 'Error en generaciÃ³n de NÃºmero de Comprobante Fiscal'
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN;	
					END 
					
					IF (@bl_af = 1) --Se debe auditar proceso fallido
					BEGIN 						
					EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
													 @id_usuario = @id_usuario ,
													 @cd_status  = 1           , 												 
													 @admsg      = @procmsg	   ;	 
					END 		  
					
					SET @ds_RespuestaJOB = @procmsg;
					SET @ds_RespuestaJOB = @procmsg;
					RETURN 1 ;
				END 
			End
			
			--	Bloqueo Cupo Credito
		 	--IF @bl_BloqueoCupoCredito = 1
		 	--BEGIN 
				--DECLARE @TotalSacCliente MONEY,@Total MONEY, @FechaTran VARCHAR(10)
				--SET @TotalSacCliente = 0
				--SELECT @FechaTran = left(replace(VALOPAR,'/',''),6) FROM Parametr WHERE parametro ='FECHACT'				
				----VALOPAR FROM Parametr WHERE parametro ='FECHACT'				
				
				--SELECT
				--	@TotalSacCliente = sum(SACTFAC)
				--FROM dbo.FACTURAS
				--WHERE IDCLIPRV = @cd_cliente_codigo
				--	AND SACTFAC <> 0
				--	--AND VENCFAC < @FechaTran
				--	AND ANOMESFAC = @FechaTran
				--	AND CLASECP ='C'
					
				--IF @TotalSacCliente = '' OR @TotalSacCliente IS NULL
				--	SET @TotalSacCliente = 0
					
				--SET @Total = @TotalSacCliente + @TotalFactura 
				
				--IF @Total > @TotalCupoCreditoCliente 
				--BEGIN
				--	IF @@TRANCOUNT > 0 
				--	BEGIN 
				--	END					
				--	SELECT 	'El Cliente excediÃ³ su Cupo CrÃ©dito.' + space(40) + CHAR(10) + CHAR(13) + 
				--		   	'Saldo: ' + convert(VARCHAR,@TotalSacCliente,1) + CHAR(10) + CHAR(13) +
				--		   	'Total CrÃ©dito Factura: ' + convert(VARCHAR,@TotalFactura,1) + CHAR(10) + CHAR(13) +
				--		   	'Cupo CrÃ©dito: ' + convert(VARCHAR,@TotalCupoCreditoCliente,1) + CHAR(10) + CHAR(13) 
				--		    'Respuesta',
				--			1 AS 'Estado' ;
				--	RETURN 1 ;
				--END 

		 	--END
/*
			--	Validando presupuesto de la licitacion
			IF @id_Licitacion <>0
		 	BEGIN 
			
				DECLARE @RestanteLicitacion MONEY , @presupuestoLicitacion MONEY
				SET	 @RestanteLicitacion = (SELECT dbo.fnza_RestanteLicitacion(@id_Licitacion))
 				SET @presupuestoLicitacion = ISNULL ((SELECT am_presupuesto FROM Licitaciones WHERE id=@id_Licitacion),0)
				IF @ValorFactura > @RestanteLicitacion 
				BEGIN
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END					
					SELECT 	'Ha sobrepasado el presupuesto de la licitaciÃ³n.' + space(40) + CHAR(10) + CHAR(13) + 
							'Presupuesto: ' + convert(VARCHAR,@presupuestoLicitacion,1) + CHAR(10) + CHAR(13) +
						   	'Saldo: ' + convert(VARCHAR,@RestanteLicitacion ,1) + CHAR(10) + CHAR(13) +
						   	'Total Factura: ' + convert(VARCHAR,@ValorFactura,1) + CHAR(10) + CHAR(13) +
							'Valor faltante: ' + convert(VARCHAR,(@RestanteLicitacion-@ValorFactura),1) + CHAR(10) + CHAR(13)	 
						    'Respuesta',
							1 AS 'Estado' ;
					RETURN 1 ;
				END 

		 	END
*/		
			--Datos de resolucion
			--verificamos si el implante depende de otro implante fullfilment
			IF EXISTS(SELECT * FROM dbo.Implantes 
						WHERE id=@id_implante AND bl_usarimplanteFullFilment = 1 AND Id_implanteFullFilment IS NOT NULL)
			BEGIN
				IF EXISTS(	
							SELECT * FROM dbo.Implantes i
							INNER JOIN Implantes iff ON iff.id = i.Id_implanteFullFilment
							WHERE i.id=@id_implante 
								And iff.ds_num_resolucion is not null
								And iff.in_num_inicial <> 0
								And iff.in_num_final <> 0
								And iff.ds_numeracion_autorizada is not null
						) 	
				BEGIN
					SELECT
						@ds_num_resolucion =iff.ds_num_resolucion,
						@dt_fecha_resolucion=iff.dt_fecha_resolucion,
						@in_num_inicial=iff.in_num_inicial,
						@in_num_final =iff.in_num_final,
						@ds_numeracion_autorizada =iff.ds_numeracion_autorizada,
						@Id_SucursalResolucion = i.id_sucursal,
						@Id_implanteResolucion = i.id	
					FROM dbo.Implantes i
					INNER JOIN Implantes iff ON iff.id = i.Id_implanteFullFilment
					WHERE i.id=@id_implante 									
				END 	
				ELSE
				BEGIN 
					SELECT
						@ds_num_resolucion =ds_num_resolucion,
						@dt_fecha_resolucion=dt_fecha_resolucion,
						@in_num_inicial=in_num_inicial,
						@in_num_final =in_num_final,
						@ds_numeracion_autorizada =ds_numeracion_autorizada,
						@Id_SucursalResolucion = id,
						@Id_implanteResolucion = NULL
					FROM Sucursales WHERE id = @id_sucursal					
				END 		
			END 
			--Implante y sucursales normales
			ELSE IF EXISTS(SELECT * FROM dbo.Implantes 
						WHERE id=@id_implante 
						      And ds_num_resolucion is not null
						      And in_num_inicial <> 0
						      And in_num_final <> 0
						      And ds_numeracion_autorizada is not null
						      ) 
			BEGIN
				SELECT
					@ds_num_resolucion =ds_num_resolucion,
					@dt_fecha_resolucion=dt_fecha_resolucion,
					@in_num_inicial=in_num_inicial,
					@in_num_final =in_num_final,
					@ds_numeracion_autorizada =ds_numeracion_autorizada,
					@Id_SucursalResolucion = id_sucursal,
					@Id_implanteResolucion = id
				FROM dbo.Implantes WHERE id = @id_implante
			END
			ELSE
			BEGIN
				IF @Id_SucursalFullFilment is NOT NULL 
				BEGIN 
					SELECT
						@ds_num_resolucion =ds_num_resolucion,
						@dt_fecha_resolucion=dt_fecha_resolucion,
						@in_num_inicial=in_num_inicial,
						@in_num_final =in_num_final,
						@ds_numeracion_autorizada =ds_numeracion_autorizada,
						@Id_SucursalResolucion = Id,
						@Id_implanteResolucion = NULL
					FROM Sucursales WHERE id = @Id_SucursalFullFilment
				END
				ELSE
				BEGIN
					SELECT
						@ds_num_resolucion =ds_num_resolucion,
						@dt_fecha_resolucion=dt_fecha_resolucion,
						@in_num_inicial=in_num_inicial,
						@in_num_final =in_num_final,
						@ds_numeracion_autorizada =ds_numeracion_autorizada,
						@Id_SucursalResolucion = Id,
						@Id_implanteResolucion = NULL
					FROM Sucursales WHERE id = @id_sucursal
				END 
			END

			IF ISNULL(@id_Contingencia,0)<>0
			BEGIN
				IF @id_implante IS NULL
				BEGIN
					SELECT @ds_num_resolucion =R.ds_num_resolucion,
						   @dt_fecha_resolucion=R.dt_fecha_resolucion,
						   @in_num_inicial=R.in_num_inicial,
						   @in_num_final =R.in_num_final,
						   @ds_numeracion_autorizada =R.ds_numeracion_autorizada,
						   @Id_SucursalResolucion = R.id_sucursal,
						   @Id_implanteResolucion = NULL 
					FROM dbo.ConfiguracionTransacciones_Adicionales CA
					INNER JOIN dbo.resoluciones R ON (R.ds_num_resolucion=CA.ds_num_resolucion AND R.id_sucursal = CA.id_sucursal AND R.id_implante IS NULL)  
					WHERE CA.id_transaccion = 2 
	    				AND CA.id_sucursal = @id_sucursal
						AND CA.id_implante IS NULL
						AND CA.cd_fuente=@cd_fuente
						AND CA.cd_serie=@cd_serie
				END
				ELSE
				BEGIN
					SELECT @ds_num_resolucion =R.ds_num_resolucion,
						   @dt_fecha_resolucion=R.dt_fecha_resolucion,
						   @in_num_inicial=R.in_num_inicial,
						   @in_num_final =R.in_num_final,
						   @ds_numeracion_autorizada =R.ds_numeracion_autorizada,
						   @Id_SucursalResolucion = R.id_sucursal,
						   @Id_implanteResolucion = R.id_implante  
					FROM dbo.ConfiguracionTransacciones_Adicionales CA
					INNER JOIN dbo.resoluciones R ON (R.ds_num_resolucion=CA.ds_num_resolucion AND R.id_sucursal = CA.id_sucursal AND R.id_implante=CA.id_implante)  
					WHERE CA.id_transaccion = 2 
	    				AND CA.id_sucursal = @id_sucursal
						AND CA.id_implante = @id_implante
						AND CA.cd_fuente=@cd_fuente
						AND CA.cd_serie=@cd_serie
				END
			END
			--Validamos las resoluciones

			IF EXISTS
					(
						SELECT * 
						FROM dbo.resoluciones 
						WHERE resoluciones.id_sucursal = @Id_SucursalResolucion
						AND (resoluciones.id_implante = @Id_implanteResolucion or @Id_implanteResolucion is NULL)
						AND ds_num_resolucion = @ds_num_resolucion
						AND resoluciones.bl_nopermitirvencidas = 1
						AND resoluciones.dt_Fechavencimiento < GETDATE()
					)
			BEGIN
				IF @@TRANCOUNT > 0 
				BEGIN 
					ROLLBACK TRAN ;		
				END	
				
				--IF @bl_generadaauto=1
				--BEGIN				
				--	SELECT 	'La resoluciÃ³n: ' + @ds_num_resolucion + ' esta Vencida. Verficar parametrizacion en el maestro de resoluciones o los datos de resoluciÃ³n de la sucursal e implante.' AS 'Respuesta', 2 AS 'Estado' ;
				--END
				--ELSE
				--BEGIN
				--	SELECT 	'La resoluciÃ³n: ' + @ds_num_resolucion + ' esta Vencida. Verficar parametrizacion en el maestro de resoluciones o los datos de resoluciÃ³n de la sucursal e implante.' AS 'Respuesta', 1 AS 'Estado' ;
				--END
				
				SET @ds_RespuestaJOB = 'La resolucion: ' + @ds_num_resolucion + ' esta Vencida. Verficar parametrizacion en el maestro de resoluciones o los datos de resoluciÃ³n de la sucursal e implante.';
				RETURN 1 
			END 

			If @Id_Cierre = 0
				SET @Id_Cierre = NULL
			
			/*inicio rgelis 2012/10/31 req.10779*/	
			if (ISNULL(@cd_TipoFact,'')='')
			BEGIN
			    SELECT @cd_TipoFact=RTrim(LTrim(Valor)) FROM dbo.parametros where Id=237				
			END
			/*inicio rgelis 2012/10/31 req.10779*/

			If @id_fac_facturaRelacionada = 0
			BEGIN
				SET @id_fac_facturaRelacionada = NUll
			END

			If @id_fac_remisionRelacionada = 0
			BEGIN
				SET @id_fac_remisionRelacionada = NUll
			END
			
			If @id_Licitacion = 0
			BEGIN
				SET @id_Licitacion = NUll
			END

			If @id_evento = 0
			BEGIN
				SET @id_evento = NUll
			END			
			
			If @id_tiqueteador_Facturador = 0
			BEGIN
				SET @id_tiqueteador_Facturador = NUll
			END	

			If @id_TipoFormaPagoProveedor = 0
			BEGIN
				SET @id_TipoFormaPagoProveedor = NUll
			END			

			If @id_MedioReservacion = 0
			BEGIN
				SET @id_MedioReservacion = NUll
			END

			IF @id_NotasAerolinea=0
			BEGIN
				SET @id_NotasAerolinea=NULL
			END
			
			DECLARE @NewFacId INTEGER 
			
			INSERT INTO dbo.fac_factura
					(
					id_sucursal,
					id_implante,
					cd_fuente,
					cd_serie,
					cd_consecutivo,
					id_usuario,
					dt_fechacont,
					dt_vence,
					cd_tercero_codigo,
					ds_tercero_nombre,
					cd_cliente_codigo,
					ds_cliente_nombre,
					ds_cliente_dir,
					ds_cliente_ciudad,
					ds_cliente_tel,
					ds_cliente_dirdesp,
					ds_cliente_email,
					ds_cliente_contacto,
					ds_cliente_contacto_email,
					id_monedas_IATA,
					am_tcambio,
					cd_vendedor,
					id_tiqueteador,
					bn_anexo,
					ds_num_resolucion, 
					in_num_inicial, 
					in_num_final, 
					ds_numeracion_autorizada,
					dt_fecha_resolucion,
					am_tcambiousd,
					id_tipoventa,
					ds_observacion,
					ds_Campo_libre1,
					ds_Campo_libre2,
					cd_fuente_Reemplaza,
					cd_serie_Reemplaza,
					cd_consecutivo_Reemplaza,											
					ds_Actividad_Economica,
				   	ds_Tarifa_ICA,
					bl_generadaauto,
					Id_Cierre,
					NCF,
					FechaCaducidad,
					cd_TipoFact, /*rgelis 2012/10/31 req.10779*/
					id_fac_remisionRelacionada, /*rgelis 2013/12/23*/
					id_fac_facturaRelacionada, /*rgelis 2013/12/23*/
					ds_DescripcionFac,	/*rgelis 2014/02/25 req.18557*/
					bl_nocont, --rgelis 2018/02/16 req.33863
					cd_CF_TipoComprobante,
					id_Licitacion, 	/*dzuniga 2014/11/13 req.22097*/
					id_Especialista,	/*dzuniga 2014/12/17*/
					id_tiqueteador_Facturador,
					id_TipoFormaPagoProveedor,
					id_MedioReservacion	,
					bl_refacturacion,
					bl_comisiona,
					id_NotasAerolinea,
					bl_interface,
					id_evento,
					bl_NoEnviarFacElectronica,
					bl_DescontarComisionCxP,
					ds_num_resolucion_Adicional,
					bl_refacturacion_contabilizar_saldos,
					in_ConsecutivoUnicoDocumento,
					id_ConsecutivoUnicoDocumento,
					id_Contingencia,
					bl_FormatoResumidoFactElectro, --rgelis 2018/10/08 Req.63202
					bl_ExigeAdjuntoFactElectro --rgelis 2019/07/25 req.90259
					)
				VALUES 
					(
					@id_sucursal,
					@id_implante,
					@cd_fuente,
					@cd_serie,
					@cd_consecutivo,
					@id_usuario,
					@dt_fechacont,
					@dt_vence,
					@cd_tercero_codigo,
					@ds_tercero_nombre,
					@cd_cliente_codigo,
					@ds_cliente_nombre,
					@ds_cliente_dir,
					@ds_cliente_ciudad,
					@ds_cliente_tel,
					@ds_cliente_dirdesp,
					@ds_cliente_email,
					@ds_cliente_contacto,
					@ds_cliente_contacto_email,
					@id_monedas_iata,
					@Tcambio,
					@cd_vendedor,
					@id_tiqueteador,
					@bn_anexo,
					@ds_num_resolucion, 
					@in_num_inicial, 
					@in_num_final, 
					@ds_numeracion_autorizada,
					@dt_fecha_resolucion,
					@am_tcambiousd,
					@id_tipoventa,
					@ds_Observacion,
					@ds_Campo_libre1,
					@ds_Campo_libre2,
					@cd_fuente_Reemplaza,
					@cd_serie_Reemplaza,
					@cd_consecutivo_Reemplaza,											
					@ds_Actividad_Economica,
				  	@ds_Tarifa_ICA,
					@bl_generadaauto,
					@Id_Cierre,
					@NCF,
					@FechaCaducidad,
					@cd_TipoFact, /*rgelis 2012/10/31 req.10779*/
					@id_fac_remisionRelacionada , /*rgelis 2013/12/23*/
					@id_fac_facturaRelacionada, /*rgelis 2013/12/23 req.10779*/
					@ds_DescripcionFac,	/*rgelis 2014/02/25 req.18557*/
					@bl_nocont, --rgelis 2018/02/16 req.33863
					@cd_CF_TipoComprobante,
					@id_Licitacion,	/*dzuniga 2014/11/13 req.22097*/
					@id_Especialista,/*dzuniga 2014/12/17*/
					@id_tiqueteador_Facturador,
					@id_TipoFormaPagoProveedor,
					@id_MedioReservacion ,
					@bl_refacturacion,
					@bl_comisiona,
					@id_NotasAerolinea,
					@bl_interface,
					@id_evento,
					@bl_NoEnviarFacElectronica,
					@bl_DescontarComisionCxP,
					@ds_num_resolucion_Adicional,
					@bl_refacturacion_contabilizar_saldos,
					@in_ConsecutivoUnicoDocumento,
					@id_ConsecutivoUnicoDocumento,
					@id_Contingencia,
					@bl_FormatoResumidoFactElectro, --rgelis 2018/10/08 Req.63202
					@bl_ExigeAdjuntoFactElectro --rgelis 2019/07/25 req.90259
					)
			
			SET @NewFacId = scope_identity() 
						
			--Grabando Items y Formas de Pago
			--PRINT '--- INICIO DE SQLSTMT ---';
			--PRINT CAST(@SqlStmt AS NTEXT);
			--PRINT '--- FIN DE SQLSTMT ---';
			EXEC dbo.sp_executesql @SqlStmt, N'@NewFacId int, @NewRmId int, @FechaFac smalldatetime, @id_monedas_iata int, @Tcambio money, @id_sucursal int, @id_implante int', @NewFacId, NULL, @dt_fechacont, @id_monedas_iata, @Tcambio, @id_sucursal, @id_implante
			
			--Grabando Anticipos de Clientes
			EXEC dbo.sp_executesql @AnticiposSqlStmt, N'@NewFacId int, @NewRemId int', @NewFacId, NULL

			--Grabando Productos
			EXEC dbo.sp_executesql @ProductosSqlStmt, N'@NewFacId int, @NewRemId int', @NewFacId, NULL			
			
			Declare @ValidarProveedor  Varchar(8000)
			set @ValidarProveedor   = ''
			SELECT @ValidarProveedor = @ValidarProveedor + 'El Proveedor: "' + rtrim(Fac_servicios.cd_proveedores) + '" ingresado en el servicio: "' + rtrim(Fac_servicios.ds_servicio) + '" no existe' + char(10) + Char(13)
			FROM Fac_servicios 
			LEFT JOIN Proveedores On Proveedores.IdProve = Fac_servicios.cd_proveedores
			WHERE Id_fac_factura = @NewFacId AND ISNULL(cd_proveedores,'') <> '' AND Proveedores.IdProve IS NULL
			
			IF isnull(@ValidarProveedor,'') <> '' 
			begin
				IF @@TRANCOUNT > 0 
				BEGIN 
					ROLLBACK TRAN ;		
				END
				SET @ds_RespuestaJOB = @ValidarProveedor;
				RETURN @retval;
			end


			Declare @ValidarSrvAsociado  Varchar(8000)
			set @ValidarSrvAsociado   = ''
			SELECT @ValidarSrvAsociado = @ValidarSrvAsociado + 'El Items: "' + CASE WHEN ISNULL(fs.ds_servicio,'')<>'' THEN rtrim(fs.ds_servicio) ELSE rtrim(fs.ds_descrip) END + '" no tiene servicio asociado y el concepto de facturaciÃ³n: "' + rtrim(cf.ds_nombre) + '" lo exige' + char(10) + Char(13)
			FROM Fac_servicios fs
			INNER JOIN ConceptoFacturacion cf  On cf.id = fs.id_ConceptoFacturacion
			WHERE Id_fac_factura = @NewFacId AND ISNULL(cf.bl_ExigirServicioAsociado,0) <> 0 AND fs.id_Fac_Servicios_Depende IS NULL
			
			IF isnull(@ValidarSrvAsociado,'') <> '' 
			begin
				IF @@TRANCOUNT > 0 
				BEGIN 
					ROLLBACK TRAN ;		
				END
				SET @ds_RespuestaJOB = @ValidarSrvAsociado;
				RETURN @retval;
			end

			--inicio dzuniga 2016/08/05 Req.32444 relacionar a las facturas la nueva factura refacturada
			IF @id_fac_facturaRefacturacion IS NOT NULL
			BEGIN
				INSERT INTO fac_factura_Refacturacion
				(
					id_fac_factura ,
					Id_fac_factura_Refacturacion ,
					dt_fecha_refacturacion,
					id_usuario
				)
				SELECT 
					codigo,
					@NewFacId,
					getdate(),
					@id_usuario
				FROM DBO.fnSplit(@id_fac_facturaRefacturacion,',',0,1) t
			END
			
			--inicio dzuniga 2016/08/05 Req.32444

			--Grabamos los Id de las cotizaciones asociadas a las facturas.
			If @ds_CotizacionesId Is Not Null
			Begin
				Declare @Count Int, @MaxFile Int, @Id_Cotizacion Int
				Declare @NSrvCotz Int, @NSrvFac Int
				Declare @TotalCotizacion MONEY, @TotalSrvCotizaFac MONEY --rgelis 2017/08/11 req.51825
				Declare @TempCot Table(id Numeric Identity( 1,1) NOT NULL,  IdC Int);
				Insert Into @TempCot(IdC)
				EXEC SpSplitMejorado @ds_CotizacionesId,','
				Set @MaxFile = @@ROWCOUNT
				
				Insert Into dbo.Cotizacion_facturas (id_cotizacion, id_fac_factura)
				Select Idc,@NewFacId From @TempCot 
					
				Set @Count = 1
				While @Count <= @MaxFile
				Begin
					Select @Id_Cotizacion = IdC From @TempCot Where Id = @Count
					Select @NSrvCotz = Count(Id) From CotizacionServicios Where Id_Cotizacion = @Id_Cotizacion
					Select @NSrvFac = Count(Id) From CotizacionServicios Where Id_Cotizacion = @Id_Cotizacion and (Id_fac_Factura is not null or Id_fac_remision is not null)
					Select @TotalSrvCotizaFac=dbo.fnza_Get_CotizacionFacturaTotal(@Id_Cotizacion) --inicio rgelis 2017/08/11 req.51825
					Select @TotalCotizacion=dbo.fnza_Get_CotizacionTotal(@Id_Cotizacion)
					
					If @TotalCotizacion>@TotalSrvCotizaFac
					Begin
						Update Cotizacion Set in_estado = Case When bl_CerrarCotizacion = 1 AND bl_grupos = 1 Then 3 Else 2 End
						where Id = @Id_cotizacion
					End
					Else If @NSrvCotz <> @NSrvFac AND @NSrvCotz > 1 --fin rgelis 2017/08/11 req.51825
					Begin
						--Parcialmente Liquidada
						Update Cotizacion Set in_estado = Case When bl_CerrarCotizacion = 1 AND bl_grupos = 1 Then 3 Else 2 End --Req. 32437 - JARG
						where Id = @Id_cotizacion
					End 
					Else 
					Begin
						--Liquidada
						Update Cotizacion Set in_estado = 3
						where Id = @Id_cotizacion
					End 
					Set @Count = @Count + 1
				End				
			End
			/*inicio rgelis 2013/05/10 inserciÃ³n de comisiones al crear la factura*/
			DECLARE @Id_Factura VARCHAR(18), @EstadoInsertarComisiones Int, @MsjInsertarComisiones Varchar(8000)
			Set @EstadoInsertarComisiones = 1
			SET @Id_Factura=CONVERT(VARCHAR(18),@NewFacId)+','
			EXEC @retval=dbo.spza_Factura_InsertarComisiones 
							@id_usuario=@id_usuario
							, @id_Facturas=@Id_Factura
							, @Estado=@EstadoInsertarComisiones
							, @Msj=@MsjInsertarComisiones
							, @MostrarMsj ='N'
				
			/*fin rgelis 2013/05/10 inserciÃ³n de comisiones al crear la factura*/
						
			/*inicio rgelis 2013/06/20 validacion de las categorias de clientes*/
			DECLARE @EstadoCategorias Int, @MsjCategorias Varchar(8000)
			Set @EstadoCategorias = 1
			IF @bl_interface = 0
			BEGIN
				EXEC @retval=dbo.spza_Factura_ValidarClientes_Categorias  
								@id_usuario=@id_usuario
								, @id_fac_factura=@NewFacId
								, @Estado=@EstadoCategorias OUTPUT
								, @Msj=@MsjCategorias OUTPUT
								, @MostrarMsj ='N'
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = @MsjCategorias;
					RETURN @retval;
				END
			END						
			/*fin rgelis 2013/06/20 validacion de las categorias de clientes*/
			
			/*inicio rgelis 2013/07/16 req.13313*/
			DECLARE @Estado Int, @Msj Varchar(8000),@id_Sys_EstadosNota INT
			Set @Estado = 1
			EXEC @retval=dbo.spza_Factura_ValidarAnticiposClientes   
							@id_usuario=@id_usuario
							, @id_fac_factura=@NewFacId
							, @Estado=@Estado OUTPUT
							, @Msj=@Msj OUTPUT
							, @MostrarMsj ='N'
			IF @retval<>0
			BEGIN 
				IF @@TRANCOUNT > 0 
				BEGIN 
					ROLLBACK TRAN ;		
				END
				SET @ds_RespuestaJOB = @Msj;
				RETURN @retval;
			END					
			/*fin rgelis 2013/07/16 req.13313*/
			SELECT @id_Sys_EstadosNota=id FROM dbo.Sys_Estados p WHERE p.id_sys_entidades = 27 AND p.bl_generacontabilizacion = 1 AND p.bl_sys = 1
			UPDATE dbo.NotasAerolinea
			SET id_fac_factura=@NewFacId
			   ,id_sys_estados=@id_Sys_EstadosNota 
			WHERE id = @id_NotasAerolinea
			
			/*Inicio - JARG - Cuando la factura tiene un solo item, validar que el tipofac de la factura sea el mismo del item*/
			If exists(Select * From dbo.Parametros Where Id = 284 And Valor = 'S')
			Begin
				SET @cd_TipoFact = '';
				
				SELECT TOP(1) @cd_TipoFact=cf.cd_TipoFact  
				FROM dbo.Fac_Factura f
					INNER JOIN dbo.Tiquetes t ON t.id_fac_factura = f.id
					INNER JOIN dbo.ConceptoFacturacion cf ON cf.id=t.in_nacionalidad
				WHERE F.Id = @NewFacId
					AND ISNULL(@cd_TipoFact,'')=''
				ORDER BY t.id DESC;

				SELECT TOP(1) @cd_TipoFact=cf.cd_TipoFact  
				FROM dbo.Fac_Factura f
					INNER JOIN dbo.fac_TAO ft ON ft.id_fac_factura = f.id
					INNER JOIN dbo.ConceptoFacturacion cf ON cf.id=ft.in_nacionalidad+3
				WHERE F.Id = @NewFacId
					AND ISNULL(@cd_TipoFact,'')=''
				ORDER BY ft.id DESC;

				SELECT TOP(1) @cd_TipoFact=cf.cd_TipoFact 
				FROM dbo.Fac_Factura f
					INNER JOIN dbo.Fac_Servicios s ON s.id_fac_factura = f.id
					INNER JOIN dbo.ConceptoFacturacion cf ON cf.id=s.id_ConceptoFacturacion
				WHERE F.Id = @NewFacId
					AND ISNULL(@cd_TipoFact,'')=''
				ORDER BY s.id DESC;

				IF (ISNULL(@cd_TipoFact,'')='' OR ISNULL(@cd_TipoFact,'')='RM')
				BEGIN
					 SELECT @cd_TipoFact = RTRIM(LTRIM(Valor)) FROM dbo.Parametros WHERE Id = 237 ;
				END

				UPDATE dbo.Fac_Factura
				Set cd_TipoFact = @cd_TipoFact
				WHERE Id = @NewFacId
			End 
			/*Fin - JARG - Cuando la factura tiene un solo item, validar que el tipofac de la factura sea el mismo del item*/
			IF @bl_generadaauto=1 --rgelis 2019/08/26 req.90259 correciones
			BEGIN
				SELECT 
					@bl_ExigeAdjuntoFactElectro = bl_ExigeAdjuntoFactElectro
				FROM dbo.Configuracion_remisiones 
				WHERE id_cliente=@cd_cliente_codigo

				IF @bl_ExigeAdjuntoFactElectro = 1
				BEGIN
					UPDATE dbo.fac_factura 
					SET bl_ExigeAdjuntoFactElectro=@bl_ExigeAdjuntoFactElectro
					WHERE id = @NewFacId
						 AND bl_ExigeAdjuntoFactElectro=0
				END
			END 
			--Facturacion Electronica
			If Exists (Select * from Parametros Where Id=306 and valor='S' AND @bl_NoEnviarFacElectronica=0 AND ISNULL(@id_Contingencia,0)=0)
			BEGIN
				if EXISTS (SELECT * FROM dbo.FUENTES WHERE IDFUENTE = @cd_fuente AND (ManejaFacturaEnLinea = 1 OR ManejaFacturaDeContingencia = 1))
				BEGIN 
					Declare @Documentra Varchar(10)
					Set @Documentra =@cd_Serie + @cd_consecutivo
					Set @Retval = 0
					Exec @Retval = SpFacturaElectronica_Peticion  
										@Categoria = 'Documentos'
										, @Operacion = 'INSERT'
										, @Llave1 = @cd_fuente
										, @Llave2 = @Documentra
										, @Llave3 = ''
										, @Llave4 = ''
										, @Fecha = @dt_fechacont	

					IF (@Retval <> 0 Or @@Error <> 0) -- Proceso fallido				
					BEGIN 
						Set @procmsg = 'Error en generaciÃ³n de FacturaciÃ³n ElectrÃ³nica'
						IF @@TRANCOUNT > 0 
						BEGIN 
							ROLLBACK TRAN;	
						END 
					
						IF (@bl_af = 1) --Se debe auditar proceso fallido
						BEGIN 						
						EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
															@id_usuario = @id_usuario ,
															@cd_status  = 1           , 												 
															@admsg      = @procmsg	   ;	 
						END 		  
					
						SET @ds_RespuestaJOB = @procmsg;
						RETURN 1 ;
					END 
				END 				
			End
			IF ISNULL(@id_Contingencia,0)<>0
			BEGIN
				Declare @DocumentraC Varchar(10)
				Set @DocumentraC =@cd_Serie + @cd_consecutivo
				Set @Retval = 0
				Exec @Retval = dbo.[SpContingencias]	 
						@Op				= 'RegDocContingenciaEvento'
					,	@Id				= @id_Contingencia
					,	@Codigo			= NULL
					,	@Nombre			= ''
					,	@Descripcion	= ''
					,	@Tipo			= ''
					,	@FuenteTal		= '' 
					,	@SerieTal		= ''
					,	@FechaInicio	= ''
					,	@Fechafin		= ''
					,	@Estado			= ''
					,	@Usuario		= ''
					,	@FuenteConsulta = @cd_fuente
					,	@SerieConsulta	= @cd_Serie
					,	@Documento		= @DocumentraC
					,	@ZxmlFuentes	= ''
				
				IF (@Retval <> 0 Or @@Error <> 0) -- Proceso fallido				
				BEGIN 
					Set @procmsg = 'Error en guardar de el documento de contingencia'
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN;	
					END 
					
					IF (@bl_af = 1) --Se debe auditar proceso fallido
					BEGIN 						
					EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
														@id_usuario = @id_usuario ,
														@cd_status  = 1           , 												 
														@admsg      = @procmsg	   ;	 
					END 		  
					
					SET @ds_RespuestaJOB = @procmsg;
					RETURN 1 ;
				END 
			END
			/*inicio rgelis 2014/12/04 req.22100*/
			IF EXISTS(SELECT * FROM dbo.Configuracion_remisiones WHERE id_cliente = @cd_cliente_codigo AND (bl_ExentoIva=1 or bl_ExentoIva2=1)) AND @bl_interface = 0
			BEGIN
				Set @Estado = 1	   
			    EXEC @retval=dbo.spza_Factura_ValidarClienteExentoIva  
							@id_usuario=@id_usuario
							, @id_fac_factura=@NewFacId
							, @Estado=@Estado OUTPUT
							, @Msj=@Msj OUTPUT
							, @MostrarMsj ='N'
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = @Msj;
					RETURN @retval;
				END
			END
			/*fin rgelis 2014/12/04 req.22100*/

			/*inicio rgelis 2015/02/27 EVT*/
			IF EXISTS(SELECT * From dbo.Parametros WHERE Id = 399 And RTRIM(Valor) = 'S')
			BEGIN
				Set @Estado = 1	   
			    EXEC @retval=dbo.spza_Factura_ValidarTiqueteAutorizacionPagoTC  
							@id_usuario=@id_usuario
							, @id_fac_factura=@NewFacId
							, @Estado=@Estado OUTPUT
							, @Msj=@Msj OUTPUT
							, @MostrarMsj ='N'
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = @Msj;
					RETURN @retval;
				END
			END
			/*fin rgelis 2015/02/27 EVT*/

			/*inicio rgelis 2016/04/26 req.31343*/
			IF EXISTS(SELECT * From dbo.Parametros WHERE Id = 448 And RTRIM(Valor) = 'S')
			BEGIN
				Set @Estado = 1	   
			    EXEC @retval=dbo.spza_Factura_ValidarTiqueteFormasPago  
							@id_usuario=@id_usuario
							, @id_fac_factura=@NewFacId
							, @Estado=@Estado OUTPUT
							, @Msj=@Msj OUTPUT
							, @MostrarMsj ='N'
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = @Msj;
					RETURN @retval;
				END
			END
			/*fin rgelis 2016/04/26 req.31343*/

			/*inicio rgelis 2015/07/28 req.25394*/
			DECLARE @MsjAlerta AS VARCHAR(8000)
			IF ISNULL(@id_Licitacion,0) <> 0
			BEGIN

				Set @Estado = 1	
			    EXEC @retval=dbo.spza_Factura_AfectarLicitacion  @id_usuario=@id_usuario,@id_Licitacion=@id_Licitacion, @id_fac_factura=@NewFacId
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = 'Error afectando la licitaciÃ³n';
					RETURN @retval;
				END
				
				Set @Estado = 1	 
			    EXEC @retval=dbo.spza_Factura_ValidarLicitacion  
							@id_usuario=@id_usuario
							, @id_fac_factura=@NewFacId
							, @Estado=@Estado OUTPUT
							, @Msj=@Msj OUTPUT
							, @MsjAlerta=@MsjAlerta OUTPUT
							, @MostrarMsj ='N'
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = @Msj;
					RETURN @retval;
				END
			END
			/*fin rgelis 2015/07/28 req.25394*/

			/*inicio rgelis 2017/01/03 req.46086*/
			IF EXISTS(SELECT * FROM dbo.Cliente_ConfiguracionVariables CV
					  INNER JOIN dbo.VariableDefinicionMaestro VM ON (VM.IDEN=CV.IDEN_Maestro AND VM.IDEN_TipoVariable=2) 
					  WHERE CV.id_cliente = @cd_cliente_codigo 
							AND CV.bl_Exige=1
							AND VM.Codigo IN('Tiquetes','FacturacionServicios')
					 ) 
			BEGIN
				Set @Estado = 1
				EXEC @retval=dbo.spza_Factura_ValidarClientes_VariablesAdicionales  
									@id_usuario=@id_usuario
									, @id_fac_factura=@NewFacId
									, @ZML_VariablesXML=@ZML_VariablesXML
									, @Estado=@Estado OUTPUT
									, @Msj=@Msj OUTPUT
									, @MostrarMsj ='N'
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = @Msj;
					RETURN @retval;
				END
			END							
			/*fin rgelis 2017/01/03 req.46086*/

			/*Inicio - JARG - 2015/02/25 Cola de Impresion*/
			DECLARE @bl_EnvCorreodespuesfacturar int, @bl_EnvCorreodespuesfacturarAuto INT
			SELECT @bl_EnvCorreodespuesfacturar = 0, @bl_EnvCorreodespuesfacturarAuto = 0
			
			SELECT 
				@bl_EnvCorreodespuesfacturar = bl_EnvCorreodespuesfacturar
				, @bl_EnvCorreodespuesfacturarAuto = bl_EnvCorreodespuesfacturarAuto
			FROM dbo.Configuracion_remisiones 
			WHERE id_cliente = @cd_cliente_codigo AND Configuracion_remisiones.bl_ControlarParametrosImp=1

			IF @bl_interface = 0
				AND (EXISTS (SELECT * FROM Parametros WHERE Id=395 and Valor = 'S') OR @bl_generadaauto = 1)
				AND (EXISTS (SELECT * FROM Parametros WHERE Id=394 and Valor = 'S') OR @bl_generadaauto = 0)
			BEGIN
				--24, 'Factura'
				INSERT INTO dbo.ColaImpresion_Documentos (Id_sys_entidades, id_documento )
				VALUES (24, @NewFacId)				
			END
			/*Fin - JARG - 2015/02/25 Cola de Impresion*/
			
			--Borramos de la automatica de tiquetes
			DELETE r
			FROM ReservasGDS_FacAuto R
			INNER JOIN (SELECT ReservasGDS.Id as IdReserva
			FROM dbo.fac_factura
			INNER JOIN dbo.Tiquetes on Tiquetes.id_fac_factura = fac_factura.id
			INNER JOIN dbo.ReservasGDS ON ReservasGDS.cd_codigo = Tiquetes.ds_records
			WHERE fac_factura.id = @NewFacId) AS c on c.IdReserva = R.id_reserva

			--Borramos de la automatica de servicios --inicio rgelis 2018/12/12 req.74918
			DELETE r
			FROM ReservasGDS_FacAuto R
			INNER JOIN (SELECT ReservasGDS.Id as IdReserva
			FROM dbo.fac_factura
			INNER JOIN dbo.Fac_Servicios on Fac_Servicios.id_fac_factura = fac_factura.id
			INNER JOIN dbo.ReservasGDS ON ReservasGDS.cd_codigo = Fac_Servicios.ds_records
			WHERE fac_factura.id = @NewFacId) AS c on c.IdReserva = R.id_reserva --fin rgelis 2018/12/12 req.74918
			
			/*Inicio - JARG - 2016/03/30 - R30713 - Bloqueo de Maximo (N) tkts por factura.*/		
			DECLARE @MaximoNumeroTktsFacturaManual INT
			SELECT @MaximoNumeroTktsFacturaManual = Valor FROM dbo.Parametros WHERE Id = 444
			IF @MaximoNumeroTktsFacturaManual <> 9999 --And @MaximoNumeroTktsFacturaManual <> 0
			Begin
				IF @bl_generadaauto = 0 AND (SELECT COUNT (*) FROM dbo.Tiquetes WHERE id_fac_factura = @NewFacId AND ds_itinerario IS NOT NULL AND ds_itinerario <> '') > @MaximoNumeroTktsFacturaManual
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SELECT 
						@retval = 1, @Estado = 1
						, @Msj = 'ExcediÃ³ el mÃ¡ximo numero de tiquetes establecidos por factura. Revisar los parÃ¡metros del sistema.' 
								+ CHAR(13) + 'Parametro: ''Numero mÃ¡ximo de tiquetes en la facturaciÃ³n manual'''
				
					SET @ds_RespuestaJOB = @Msj;
					RETURN @retval;
				END 
			End
			/*Fin - JARG - 2016/03/30 - R30713 - Bloqueo de Maximo (N) tkts por factura.*/
			
			/*inicio rgelis 2017/02/21 req.47358*/
			IF EXISTS(SELECT * From dbo.Parametros WHERE Id = 479 And RTRIM(Valor) = 'S')
			BEGIN
				Set @Estado = 1	   
			    EXEC @retval=dbo.spza_Factura_ValidarTiqueteGr  
							@id_usuario=@id_usuario
							, @id_fac_factura=@NewFacId
							, @Estado=@Estado OUTPUT
							, @Msj=@Msj OUTPUT
							, @MostrarMsj ='N'
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = @Msj;
					RETURN @retval;
				END
			END
			/*fin rgelis 2017/02/21 req.47358*/		

			/*inicio rgelis 2017/08/08 req.51825*/
			IF EXISTS(SELECT * From dbo.Parametros WHERE Id = 491 And RTRIM(Valor) = 'S')
			BEGIN
				Set @Estado = 1	   
			    EXEC @retval=dbo.spza_Factura_ValidarFacturaParcial  
							@id_usuario=@id_usuario
							, @id_fac_factura=@NewFacId
							, @Estado=@Estado OUTPUT
							, @Msj=@Msj OUTPUT
							, @MostrarMsj ='N'
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = @Msj;
					RETURN @retval;
				END
			END
			/*fin rgelis 2017/08/08 req.51825*/

			--inicio rgelis 2018/11/22 req.74261
			Set @Estado = 1	   
			EXEC @retval=dbo.spza_Factura_ValidarConceptos  
						@id_usuario=@id_usuario
						, @id_fac_factura=@NewFacId
						, @Estado=@Estado OUTPUT
						, @Msj=@Msj OUTPUT
						, @MostrarMsj ='N'
			IF @retval<>0
			BEGIN 
				IF @@TRANCOUNT > 0 
				BEGIN 
					ROLLBACK TRAN ;		
				END
				SET @ds_RespuestaJOB = @Msj;
				RETURN @retval;
			END
			--fin rgelis 2018/11/22 req.74261

			--inicio rgelis 2019/07/30 req.90132
			IF EXISTS(SELECT * FROM dbo.Configuracion_remisiones WHERE id_cliente = @cd_cliente_codigo AND (bl_BloqCupoCrd=1 or bl_BloqDiaVence = 1 or bl_BloqManual = 1 or bl_EnvCorreoBloqDiaVence=1 or bl_EnvCorreoBloqCupoCrd=1 OR bl_AlertaAgotaCupoCrd=1)) --AND @bl_interface = 0
			BEGIN
				Set @Estado = 1	   
				EXEC @retval=dbo.spza_Factura_ValidarCupoCredito 
							@id_usuario=@id_usuario
							, @id_fac_factura=@NewFacId
							, @Estado=@Estado OUTPUT
							, @Msj=@Msj OUTPUT
							, @MsjAlerta=@MsjAlerta OUTPUT
							, @MostrarMsj ='N'
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = @Msj;
					RETURN @retval;
				END
			END
			--fin rgelis 2019/07/30 req.90132
			
			
			Declare @TAjusteIVA TABLE 	(	am_totalBaseFac MONEY,	am_totalIVAFac MONEY,	am_totalFac MONEY,	am_totalBase_Correccion MONEY,	am_totalIVA_Correccion MONEY,	am_total_Correccion MONEY,	am_total_Diferencia MONEY,	idDocumento INT,	in_tipo INT,	id_item INT,	in_tipoitem INT,	id_cargo INT,	id_imp INT,	am_cargo MONEY,	am_imp MONEY,	am_total MONEY,	am_porcentaje MONEY,	am_impdecimal MONEY,	am_imp1 MONEY,	am_toleranciaMas1 MONEY,	am_imp2 MONEY,	am_toleranciaMenos1 MONEY	,ds_descripcion varchar(8000), am_deltaCorreccion money, am_total_Diferencia_OUT money, Documento Varchar(25))
			Declare @TAjusteIVARes TABLE 	(ds_respuesta VARCHAR(50), in_Estado INT, am_totalBaseFac MONEY,	am_totalIVAFac MONEY,	am_totalFac MONEY,	am_totalBase_Correccion MONEY,	am_totalIVA_Correccion MONEY,	am_total_Correccion MONEY,	am_total_Diferencia MONEY,	idDocumento INT,	in_tipo INT,	id_item INT,	in_tipoitem INT,	id_cargo INT,	id_imp INT,	am_cargo MONEY,	am_imp MONEY,	am_total MONEY,	am_porcentaje MONEY,	am_impdecimal MONEY,	am_imp1 MONEY,	am_toleranciaMas1 MONEY,	am_imp2 MONEY,	am_toleranciaMenos1 MONEY	,ds_descripcion varchar(8000), am_deltaCorreccion money, am_total_Diferencia_OUT money, Documento Varchar(25))
			Declare @am_total_Diferencia_OUT MONEY
			SELECT @FacturadorElect = Valor From dbo.Parametros Where Id=307
			IF (Dbo.[fnza_Get_ValorInterfazVariable](@FacturadorElect,131,'Validar_IVA_facturacion') ='SI') AND @bl_omitir_Validar_IVA_facturacion = 0 AND @bl_generadaauto = 0
			BEGIN

				INSERT INTO @TAjusteIVA 
				EXEC @retval = dbo.[spza_FacturaRemision_AjustarIVA] @id_usuario = @id_usuario, @IdDocumento = @NewFacId, @am_total_Diferencia_OUT = @am_total_Diferencia_OUT OUTPUT, @bl_vista_previa = 0, @Debug = 0,@bl_solo_validar = 1, @Tipo = 1

				Declare @Valor_tolerancia_IVA MONEY
				SELECT @Valor_tolerancia_IVA = isnull(Dbo.[fnza_Get_ValorInterfazVariable](@FacturadorElect,131,'Valor_tolerancia_IVA'),2)
				--select @Valor_tolerancia_IVA as '@Valor_tolerancia_IVA'
				IF ABS(@am_total_Diferencia_OUT) >  = ABS(ISNULL(@Valor_tolerancia_IVA,0))
				BEGIN

					IF @@TRANCOUNT > 0
					BEGIN 
						ROLLBACK TRAN ;		
					END

					SET @ds_RespuestaJOB = 'Se necesita realizar ajuste de IVA';return 1
				END
			END 
			BEGIN
				IF @bl_omitir_Validar_IVA_facturacion <>0 AND @bl_generadaauto = 0
				BEGIN
					--SET @ZML_AjusteIvaXML=REPLACE(@ZML_AjusteIvaXML,'cd_items VARCHAR(50),','')
					--SET @ZML_AjusteIvaXML=REPLACE(@ZML_AjusteIvaXML,'''''Se necesita realizar ajuste de IVA'''',2,','')
					SET @ZML_AjusteIvaXML=REPLACE(@ZML_AjusteIvaXML,'''''','''')
					INSERT INTO @TAjusteIVARes
					EXEC(@ZML_AjusteIvaXML)
					IF EXISTS(SELECT * FROM @TAjusteIVARes WHERE am_deltaCorreccion <> 0)
					BEGIN
						DELETE FROM @TAjusteIVA
						INSERT INTO @TAjusteIVA 
						EXEC @retval = dbo.[spza_FacturaRemision_AjustarIVA] @id_usuario = @id_usuario, @IdDocumento = @NewFacId, @am_total_Diferencia_OUT = @am_total_Diferencia_OUT OUTPUT, @bl_vista_previa = 1, @Debug = 0,@bl_solo_validar = 0, @Tipo = 1	
						IF @retval<>0 
						BEGIN 
   				
   							IF @@TRANCOUNT > 0 
							BEGIN 
								ROLLBACK TRAN ;		
							END
							SELECT @Estado = 1
								 , @Msj = 'Error el Ajustar los valores del iva';
							SET @ds_RespuestaJOB = @Msj;
							RETURN @retval;
						END
					END
				END	
			END

			IF NOT EXISTS(SELECT TOP 1 F.id FROM dbo.fac_factura F
						LEFT JOIN dbo.Tiquetes T ON T.id_fac_factura=F.id
						LEFT JOIN dbo.Fac_Tao FT ON FT.id_fac_factura=F.id
						LEFT JOIN dbo.Fac_Servicios FS ON FS.id_fac_factura=F.id
					  WHERE T.id IS NOT NULL OR FT.id IS NOT NULL OR FS.id IS NOT NULL
					 )
			BEGIN
				IF @@TRANCOUNT > 0 
				BEGIN 
					ROLLBACK TRAN ;		
				END

				SELECT @Estado = 1
					  , @Msj = 'Error en el crear factura no tiene item(tiquetes, tao o servicios)';
				SET @ds_RespuestaJOB = @Msj;
				RETURN 1;
			END

			--Contabilizando la Factura
			SET @retval=0 --inicio rgelis 2018/02/16 req.33683
			IF (NOT (dbo.fnza_Get_FacturaTotal(@NewFacId) = 0) AND @bl_nocont = 0) 
			BEGIN
				EXEC @retval = dbo.spza_Factura_Contabilizar @id_usuario,@NewFacId,1,@CodigoArchivoFisico
			END --fin rgelis 2018/02/16 req.33683

			IF @retval<>0 
			BEGIN 
   				
   				IF @@TRANCOUNT > 0 
				BEGIN 
					ROLLBACK TRAN ;		
				END
				
				IF (@bl_af = 1) 
				BEGIN 										
					EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
													 @id_usuario = @id_usuario ,
													 @cd_status  = 1           , 												 
													 @admsg      = 'Error en el proceso de contabilizacion',
								 					 @msgparams  = @msg;
				END
				RETURN @retval;
			END 
			ELSE 
			BEGIN 
				Set @DocumentoCont = @cd_serie + @cd_consecutivo
				If	Exists(Select * From Parametros Where Id = 232 and Valor = 'S')
						And 
					Not Exists(Select * from Clientes Where IndNCF = 1 And IdCliente = @cd_cliente_codigo)
				Begin
					Set @ErrorNCF = 1
					Exec @ErrorNCF = spCF_DocumentoControl   
							@Op = 'I', 
							@Fuente	= @cd_fuente, 
							@Documento = @DocumentoCont, 
							@NCF = @NCF

					IF (Isnull(@ErrorNCF, 0) <> 0 Or @@Error <> 0) --
					BEGIN 
						Set @procmsg = 'Error al actualizar Control Documentos NCF.'
						IF @@TRANCOUNT > 0 
						BEGIN 
							ROLLBACK TRAN;	
						END 
						
						IF (@bl_af = 1) --Se debe auditar proceso fallido
						BEGIN 						
						EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
														 @id_usuario = @id_usuario ,
														 @cd_status  = 1           , 												 
														 @admsg      = @procmsg	   ;	 
						END 		  
						
						SET @ds_RespuestaJOB = @procmsg;
						RETURN 1 ;
					END 
											
							
				End
				-----------------------------------------------------------------
				----ZOL - JARG - 2016/04/19 - R29308
				-----------------------------------------------------------------
				Set @Estado = 1	
			    EXEC @retval=dbo.Spza_Interfaces_ProcesarReservaXFactura  @id_usuario=@id_usuario, @id_fac_factura=@NewFacId
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = 'Error actualizando la reserva';
					RETURN @retval;
				END
				-----------------------------------------------------------------
				----FIN ZOL - JARG - 2016/04/19 - R29308
				-----------------------------------------------------------------				
				DECLARE @msglog AS VARCHAR(8000)
				SET @msglog='La factura ' + @cd_fuente+'-'+@cd_serie+@cd_consecutivo + ' fue creada exitosamente'

				--Determinando si se debe auditar el proceso exitoso
				IF (@bl_as = 1) 
				BEGIN 										
					EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
													 @id_usuario = @id_usuario ,
													 @cd_status  = 1           , 												 
													 @admsg      = @msglog     ,
								 					 @msgparams  = NULL;
				END 			 			
				
	 		 	--Si la transaccion fue creada en el procedimiento entonces se actualiza--
				IF (XACT_STATE() <> 0) and (@@TRANCOUNT > 0) 
		   	    BEGIN 
				   COMMIT TRAN;				   
				END
				
				--Obtenemos los datos de los Rc automatico
				--SELECT 
				--	@cd_fuenteRC = cd_fuente_RcAuto
				--	, @cd_serieRC = cd_serie_RcAuto
				--	, @cd_consecutivoRC = cd_consecutivo_RcAuto
				--	, @cd_fuenteRCOtr = cd_fuente_RcOtrAuto
				--	, @cd_serieRCOtr = cd_serie_RcOtrAuto
				--	, @cd_consecutivoRCOtr = cd_consecutivo_RcOtrAuto
				--FROM dbo.fac_factura
				--WHERE id = @NewFacId
 
				--SELECT 	
				--	@cd_fuente+'-'+@cd_serie+@cd_consecutivo
				--	+'-'+CONVERT(VARCHAR(18),@NewFacId)									AS 'Respuesta', 
			 -- 		0																	AS 'Estado',
				--	IsNull(@cd_fuenteRC+'-'+@cd_serieRC+@cd_consecutivoRC,'')			AS 'RcAutomsg',
				--	IsNull(@cd_fuenteRCOtr+'-'+@cd_serieRCOtr+@cd_consecutivoRCOtr,'')	AS 'RcOtrAutomsg',
			 -- 		@Resolucionmsg														AS 'Resolucionmsg',
			 -- 		@NCF																AS 'NCF',
				--	@FechaCaducidad														AS 'FechaCaducidad'
				/*inicio rgelis 2012/10/11 req.10814*/
				IF @bl_generadaauto = 1	AND ISNULL(@Resolucionmsg,'')<> '' 
				BEGIN
					SET @MsjAlerta=ISNULL((@MsjAlerta+CHAR(13)+CHAR(10)),'')+ISNULL(@Resolucionmsg,'')
				END
				
				SELECT 	
					@cd_fuente+'-'+@cd_serie+@cd_consecutivo
					+'-'+CONVERT(VARCHAR(18),@NewFacId)									AS 'Respuesta', 
			  		0																	AS 'Estado',
					RC.ID																AS 'id_ReciboCaja',
					RC.id_FormaPago														AS 'id_FormaPago',
					FP.ds_nombre														AS 'ds_FormaPago',
					RC.cd_Fuente														AS 'cd_fuente',
					RC.cd_Serie															AS 'cd_serie',
					RC.cd_Consecutivo													AS 'cd_consecutivo',
					CASE RC.in_Tipo WHEN 1 THEN 'RC de Tiquetes' 
										   ELSE 'RC de otros Items'
									END													AS 'ds_Tipo',
					RC.am_valor															AS 'am_valor',
			  		CASE 
						WHEN 
							r.ds_num_resolucion IS NOT NULL 
							AND DATEDIFF(DAY,F.dt_fecha,r.dt_Fechavencimiento)<=ISNULL(r.in_diasvencimiento,0)
							AND ISNULL(r.in_diasvencimiento,0) > 0
							AND r.bl_alertarvencimiento = 1
							THEN 'Faltan ' + convert(VARCHAR,DATEDIFF(DAY,F.dt_fecha,r.dt_Fechavencimiento))  + ' dÃ­as para el vencimiento de la resoluciÃ³n'
						ELSE @Resolucionmsg END											AS 'Resolucionmsg',
			  		ISNULL(@NCF,'')														AS 'NCF',
					ISNULL(@FechaCaducidad,@dt_vence)									AS 'FechaCaducidad',
					ISNULL(@MsjAlerta,'')												AS 'ds_Alerta',
					@in_ConsecutivoUnicoDocumento										AS 'in_ConsecutivoUnicoDocumento',
					case when cd_fuente_NCausacionSrvTer is not null then isnull(cd_fuente_NCausacionSrvTer,'')+'-'+isnull(cd_serie_NCausacionSrvTer,'') + isnull(cd_consecutivo_NCausacionSrvTer,'') else '' end											AS 'DocumentoCausacionCxP'
				FROM dbo.fac_factura As F
					LEFT JOIN dbo.Fac_RecibosCaja As RC ON RC.id_fac_factura=F.id
					LEFT JOIN dbo.FormasPago As FP ON FP.id=RC.id_FormaPago 
					LEFT JOIN dbo.resoluciones r ON r.id_sucursal = F.id_sucursal AND r.ds_num_resolucion = F.ds_num_resolucion
				WHERE F.id = @NewFacId 	
				/*fin rgelis 2012/10/11 req.10814*/

				SELECT TOP 1 
					@ds_RespuestaJOB = ISNULL('Factura Creada: '+F.cd_fuente+'-'+F.cd_serie+F.cd_consecutivo+'-'+CONVERT(VARCHAR(18),F.id), '') + 
						CASE WHEN ISNULL(@MsjAlerta, '') <> '' THEN ' - Alerta: ' + @MsjAlerta ELSE '' END +
						CASE WHEN ISNULL(
							CASE WHEN r.ds_num_resolucion IS NOT NULL AND DATEDIFF(DAY,F.dt_fecha,r.dt_Fechavencimiento)<=ISNULL(r.in_diasvencimiento,0) AND ISNULL(r.in_diasvencimiento,0) > 0 AND r.bl_alertarvencimiento = 1 THEN 'Faltan ' + convert(VARCHAR,DATEDIFF(DAY,F.dt_fecha,r.dt_Fechavencimiento))  + ' dÃ­as para el vencimiento de la resoluciÃ³n' ELSE @Resolucionmsg END
						, '') <> '' THEN ' - Res: ' + 
							CASE WHEN r.ds_num_resolucion IS NOT NULL AND DATEDIFF(DAY,F.dt_fecha,r.dt_Fechavencimiento)<=ISNULL(r.in_diasvencimiento,0) AND ISNULL(r.in_diasvencimiento,0) > 0 AND r.bl_alertarvencimiento = 1 THEN 'Faltan ' + convert(VARCHAR,DATEDIFF(DAY,F.dt_fecha,r.dt_Fechavencimiento))  + ' dÃ­as para el vencimiento de la resoluciÃ³n' ELSE @Resolucionmsg END
						ELSE '' END +
						CASE WHEN ISNULL(RC.cd_fuente, '') <> '' THEN ' - Pago: ' + ISNULL(FP.ds_nombre, '') + ' ' + ISNULL(RC.cd_Fuente, '') + '-' + ISNULL(RC.cd_Serie, '') + '-' + ISNULL(RC.cd_Consecutivo, '') + ' (' + CASE RC.in_Tipo WHEN 1 THEN 'RC de Tiquetes' ELSE 'RC de otros Items' END + ') ' + ISNULL(CAST(RC.am_valor AS VARCHAR), '') ELSE '' END
				FROM dbo.fac_factura As F
					LEFT JOIN dbo.Fac_RecibosCaja As RC ON RC.id_fac_factura=F.id
					LEFT JOIN dbo.FormasPago As FP ON FP.id=RC.id_FormaPago 
					LEFT JOIN dbo.resoluciones r ON r.id_sucursal = F.id_sucursal AND r.ds_num_resolucion = F.ds_num_resolucion
				WHERE F.id = @NewFacId;
				
				RETURN @retval;
				
			END
		
			------------------------------------------------------------------------
			
	    END TRY 
    
    	-- Bloque CATCH (Manejo de excepciones)
    	BEGIN CATCH 
 
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
	   	        SET @ds_RespuestaJOB = @msg;
				RETURN @retval;
		    END
		    
		    -- Registro bloqueado / Conflicto de actualizacion
		    ELSE 
		    IF ERROR_NUMBER() IN (1205, 3960)
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
							'Procedimiento: ' + 'spza_FacturaJOB_Crear'							+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							'Linea: ' + isnull(CAST(ERROR_LINE() 	   AS VARCHAR(10)),'')      + CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) ; 							
	
				--Se debe auditar proceso fallido
				IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar	@id_proceso = @idproce   ,
										 			 			@id_usuario = @id_usuario ,
										 			 			@cd_status  = 0           , 
										 			 			@admsg      = @msg	  ;	
				--RAISERROR (@msg,16,126);
				--SET @ds_RespuestaJOB = @msg;
				SET @ds_RespuestaJOB = @msg;
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
  		--RAISERROR (@msg,16,127);
  		SET @ds_RespuestaJOB = @msg;
		RETURN @retval;
  	END   	
    
    RETURN @retval;
END
GO



GO

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


GO

IF OBJECT_ID('dbo.spza_GDSFacturacionAutoJOB_Consultar', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spza_GDSFacturacionAutoJOB_Consultar;
GO

CREATE PROCEDURE [dbo].[spza_GDSFacturacionAutoJOB_Consultar]
	-- Parametros del procedimiento
	@id_usuario INT,
	@cd_sucursal VARCHAR(MAX) = '',
	@cd_implante VARCHAR(MAX) = '',
	@bl_factura INT = 1,
	@bl_cotizacion INT = 0
With Encryption
AS
BEGIN
	-- SET NOCOUNT ON: Previene que conjuntos de resultados extras interfieran con 
	-- expresiones SELECT
	SET NOCOUNT ON;
	DECLARE 
		@FiltrarSucursalFactAuto BIT
		,@FiltrarImplanteFactAuto BIT
		,@AgruparFacturasAutomaticasXCliente VARCHAR(1),@MaximoNumeroTktsFacturaAutomatica INT /*JARG - 2016/03/30 - R30713 - Bloqueo de Maximo (N) tkts por factura.*/		
		,@GenerarCotizacion BIT --rgelis 2018/04/09 req.56942
		,@SoloUtilizarConfgClienteFacAuto BIT --rgelis 2018/04/13 req.58321
	DECLARE  @TableResultVacio TABLE (	PNR VARCHAR (62),	Tipo VARCHAR (4),	Servicio VARCHAR (123),	Descrip VARCHAR (78),	id INT ,	iden_gds INT,	ds_fecha SMALLDATETIME,	cd_tiqueteador VARCHAR (6),	cd_vendedor CHAR (3),	cd_cliente CHAR (10),	am_highfare MONEY,	am_lowfare MONEY,	am_fare MONEY,	ds_reasoncode CHAR (2), ds_cliname VARCHAR (50),	ds_clidir VARCHAR (50),	ds_clicity VARCHAR (50),	ds_cliid CHAR (10),	ds_itinerario VARCHAR (250),	ds_clases VARCHAR (61),	in_nacionalidad TINYINT,	id_air INT ,	ds_pax_number TINYINT,	ds_pax_firstnm VARCHAR (30),	ds_pax_lastnm VARCHAR (30),	ds_pax_prefix CHAR (3),	ds_tkt_number CHAR (10),	ds_tkt_prefix CHAR (3),	ds_aero_code CHAR (3),	ds_moneda CHAR (3),	am_tarifa MONEY,	am_iva MONEY,	am_tua MONEY,	am_comb MONEY,	am_vat MONEY,	ds_cc_code CHAR (2),	ds_cc_number VARCHAR (25),	am_tao MONEY,	am_ivatao MONEY,	am_cap MONEY,	am_ivacap MONEY,	ds_cc_code2 CHAR (2),	ds_cc_number2 CHAR (16),	am_fp1 MONEY,	am_fp2 MONEY,	cd_tktrevisado VARCHAR (14),	am_TarifaContado MONEY,	am_IvaContado MONEY,	am_OtrosContado MONEY,	am_TarifaCredito MONEY,	am_IvaCredito MONEY,	am_OtrosCredito MONEY,	am_Comision MONEY,	cd_clitipodoc VARCHAR (100),	cd_clitipotercero CHAR (1),	ds_clirazoncial VARCHAR (250),	ds_cliname2 VARCHAR (60),	ds_clilastname VARCHAR (60),	ds_clilastname2 VARCHAR (60),	cd_clipais VARCHAR (25),	ds_clitel VARCHAR (25),	cd_TipoTransaccion VARCHAR (1),	Fecha_Salida SMALLDATETIME,	Fecha_Llegada SMALLDATETIME,	Id_Srv INT,	cd_conceptofacturacion INT,	cd_tiposervicio INT,	cd_proveedores INT,	ds_proveedores INT,	id_car INT,	dt_entrega INT,	in_cars INT,	cd_carcode INT,	cd_conf_car INT,	cd_citysalida INT,	dt_retorno INT,	cd_cartype INT,	cd_currency INT,	am_tarifacar INT,	cd_bookingsource INT,	cd_ratecode INT,	id_htl INT,	dt_checkin INT,	in_guests INT,	cd_confirmation INT,	cd_city INT,	cd_htlchain INT,	dt_checkout INT,	in_noches INT,	ds_htlname INT,	in_habs INT,	cd_bed INT,	cd_ratecode_htl INT,	cd_htlcur INT,	am_htltarifa INT,	cd_agcur INT,	am_agtarifa INT,	ds_dir1 INT,	ds_tel INT,	ds_fax INT,	cd_centrocosto VARCHAR (50),	NumTktConj INT,	Respuesta VARCHAR (1),	ds_solicita VARCHAR (200),	cd_pax_CC VARCHAR (20),	ds_lapsoviaje VARCHAR (50),	ds_archivo VARCHAR (250),	ds_Observaciones VARCHAR (8000),	ds_ClienteEmail VARCHAR (100),	cd_sucursal CHAR (5),	cd_implante CHAR (5),	bl_ClienteActualizar BIT,	bl_NotificacionMPD BIT,	cd_FormaPagoTAO VARCHAR (3),	cd_TarjetaCreditoTAO VARCHAR (4),	cd_NumeroTarjetaTAO VARCHAR (25),	cd_VencimientoTarjetaTAO CHAR (6),	cd_NumeroPolizaTAO VARCHAR (50),	cd_AnexoPolizaTAO VARCHAR (50),	am_PorDesFormaPagoTA NUMERIC (8, 4),	cd_Penalidad CHAR (14),	ds_cc_vence CHAR (5),	ds_cc_vence2 CHAR (5),	ds_cc_autorizacion INT,	ds_cc_autorizacion2 VARCHAR (25),	ds_cc_voucher INT,	ds_cc_voucher2 VARCHAR (10),	ds_AutorizacionTarjetaTAO INT,	ds_VoucherTarjetaTAO INT,	am_fptao MONEY,	in_cc_cuotas INT,	in_cc_cuotas2 INT,	in_cuotasTarjetaTAO INT,	cd_TipoTarifaTAO VARCHAR (25),	cd_TipoTiquete CHAR (3),	am_TasaCambio MONEY,	cd_tiqueteador_facturador CHAR (3),	bl_ahorro BIT,	in_CantidadTarifaTAO INT,	in_CantidadSegmentoTAO INT,	cd_tourcode VARCHAR (25),	ds_contrato VARCHAR (25),	cd_PasaportePax VARCHAR (25),	ds_itinerarioaerolinea VARCHAR (128),	ds_tkt_prefixIata CHAR (3),	ds_Evento VARCHAR (250),	cd_iata VARCHAR (25),	ds_aero_codeIata CHAR (3), cd_Ahorro CHAR (3) )	  /*rgelis 2016/09/09 req.33775*/
	DECLARE @TValorInterfazGDSParametro TABLE(id INT IDENTITY, id_GDS INT, id_sys_entidades INT, cd_codigo_maestro VARCHAR(50), cd_dato_maestro VARCHAR(500), ds_valor VARCHAR(500)) --rgelis 2019/10/10 req.92991

	SET	@FiltrarSucursalFactAuto = 0;
	SELECT @FiltrarSucursalFactAuto = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=426 /*JARG 2015/07/25 - filtrar por sucursal facturacion automatica -M&M*/
	SET	@FiltrarImplanteFactAuto = 0;
	SELECT @FiltrarImplanteFactAuto = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=426 /*JARG 2015/07/25 - filtrar por sucursal facturacion automatica -M&M*/

	IF ISNULL(@cd_sucursal,'')='' AND ISNULL(@cd_implante,'')=''
	BEGIN
		SET	@FiltrarSucursalFactAuto = 0;
		SET	@FiltrarImplanteFactAuto = 0;
	END

	SELECT @AgruparFacturasAutomaticasXCliente = Valor FROM dbo.Parametros WHERE Id = 445
	SELECT @MaximoNumeroTktsFacturaAutomatica = Valor FROM dbo.Parametros WHERE Id = 446
	SELECT 
		@GenerarCotizacion = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END FROM dbo.Parametros WHERE Id = 526 --rgelis 2018/04/09 req.56942
		AND @bl_cotizacion = 1 --JRamirez 20200609
	
	SET @SoloUtilizarConfgClienteFacAuto=0
	SELECT @SoloUtilizarConfgClienteFacAuto = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END FROM dbo.Parametros WHERE Id = 525 --rgelis 2018/04/13 req.58321
	--IF NOT EXISTS(  SELECT r.id  
	--				FROM dbo.ReservasGDS r
	--				INNER JOIN dbo.ReservaGDS_Detalles tkt ON (r.id=tkt.id_reserva)
	--				INNER JOIN dbo.ReservasGDS_FacAuto fpa ON fpa.id_reserva = r.id
	--				WHERE tkt.bl_usada = 0 	AND (fpa.cd_sucursal = @cd_sucursal  OR @FiltrarSucursalFactAuto = 0)
	--				)
	--BEGIN
	--	SELECT * FROM @TableResultVacio
	--	RETURN 1
	--END

	/*
	DECLARE @Parametro INT
	SET @Parametro = 5

	SELECT 
		Cliente + '-'  + CONVERT(VARCHAR,(ROW_NUMBER()   OVER(PARTITION BY Cliente ORDER BY Cliente DESC)-1) / @MaximoNumeroTktsFacturaAutomatica)
		, Tiquete 
		,Contador=ROW_NUMBER()   OVER(PARTITION BY Cliente ORDER BY Cliente DESC)
		, Agrupado = (ROW_NUMBER()   OVER(PARTITION BY Cliente ORDER BY Cliente DESC)-1) / @Parametro
	FROM #Reservas 
	*/
	
	INSERT INTO @TValorInterfazGDSParametro(id_GDS,id_sys_entidades,cd_codigo_maestro,cd_dato_maestro,ds_valor)
	SELECT id_GDS				=	I.id_GDS
		  ,id_sys_entidades		=	E.id_sys_entidades
		  ,cd_codigo_maestro	=	E.cd_codigo_maestro
		  ,cd_dato_maestro		=	E.cd_dato_maestro
		  ,ds_valor				=	E.cd_codigo_equivalente
	FROM dbo.Interfaces_Equivalencia E
		INNER JOIN dbo.Interfaces I ON I.id = E.id_Interfaces


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
			@tc			INT 			, -- Numero de transacciones abiertas
			@msg	    VARCHAR(8000)   , -- Mensaje retornado por el sistema
			@retval		TINYINT 		, -- Valor de retorno de este procedimiento: 0:Exito ; 1:Error(Bloque Catch)
			@bl_BSP     BIT				, -- Solo trabaja con BSP
			@bl_tomarvendedorcliente BIT, -- Filtro para tomar vendedor del cliente /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
			@bl_TomarSucursalImplantePCCGDS BIT,
			@TomarTC_Voucher_Auto_ZeusTC BIT,
			@bl_GenerarFacturaXTiquete BIT,
			@bl_tomarnacionalidadDetalles BIT,
			@bl_tomartiposervicionacionalidad BIT,
			@cd_tiposervicionacional VARCHAR(3),
			@cd_tiposerviciointernacional VARCHAR(3),
			@cd_TCTipoTarjetaMostrarNumero VARCHAR(3),
			@bl_tomarFPAirplusTkt BIT,
			@bl_tomarFPTaoTkt BIT;
	
	SELECT 	@idproce 			 = 123,
			@retry				 = 1 		   ,
			@retrycont			 = 0		   ,
			@tc 			 	 = @@TRANCOUNT ,
			@retval				 = 0;
  	
  	-- Manejo de tiempo de espera y de reintentos por bloqueo de tablas/registros  
   	SELECT @maxretries = 3
	SELECT @timeout    = 3000
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
			
	   

	   			--inicio dzuniga 2016/05/16  LLEVAR LOS EMD A UNA MISMA NACIONALIDAD 
			DECLARE @TAerolineas Table (entidad char(3))
			DECLARE @bl_EMD AS char(1)
			DECLARE @nacionalidad_EMD AS INT
			DECLARE @cd_TipoDocEMD AS VARCHAR(3)
			DECLARE @cd_categoria AS VARCHAR(25)
			--aerolineas para cambiar la nacionalidad de las EMD
			INSERT INTO @TAerolineas
			SELECT e.cd_siglas FROM dbo.fnSplit( (SELECT  VALOR FROM Parametros WHERE id = 452 ),',',0,1) T
			INNER JOIN Entidades E ON E.cd_codigo = T.Codigo

			SET @bl_EMD = isnull ((SELECT  VALOR FROM Parametros WHERE id = 451) ,'N')
			SET @nacionalidad_EMD = CASE WHEN (SELECT  VALOR FROM Parametros WHERE id = 453 )='Nacional' THEN 1 ELSE 2 END
			SELECT @cd_TipoDocEMD=LTRIM(RTRIM(VALOR)) FROM Parametros WHERE id = 369
			--FIN dzuniga 2016/05/16



			--Instrucciones del procedimiento-----------------------------------------
				SELECT 
					@bl_BSP = 0
					, @bl_tomarvendedorcliente = 0 /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
					, @bl_TomarSucursalImplantePCCGDS = 0
					, @TomarTC_Voucher_Auto_ZeusTC = 0
					, @bl_GenerarFacturaXTiquete = 0
				
				SELECT @bl_tomarvendedorcliente = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=367 /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
				SELECT @bl_TomarSucursalImplantePCCGDS = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=373 
				SELECT @bl_BSP = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=327
				SELECT @TomarTC_Voucher_Auto_ZeusTC = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=408
				SELECT @bl_GenerarFacturaXTiquete = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=423 /*JARG 2015/07/25 - Generar una factura por tiquete, en la facturacion automatica -M&M*/
				SELECT @cd_categoria = rtrim(ltrim(Valor)) FROM dbo.Parametros WHERE id=387
				SELECT @bl_tomarnacionalidadDetalles = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=582
				SELECT @bl_tomartiposervicionacionalidad = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=584 
				SELECT @cd_tiposervicionacional = rtrim(ltrim(Valor)) FROM dbo.Parametros where Id=585
				SELECT @cd_tiposerviciointernacional = rtrim(ltrim(Valor)) FROM dbo.Parametros where Id=586
				SELECT @cd_TCTipoTarjetaMostrarNumero = rtrim(ltrim(Valor)) FROM dbo.Parametros where Id=573
				SELECT @bl_tomarFPAirplusTkt = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=608
				SELECT @bl_tomarFPTaoTkt = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=609
				SET @bl_tomarFPAirplusTkt=ISNULL(@bl_tomarFPAirplusTkt,0)
				SET @bl_tomarFPTaoTkt=isnull(@bl_tomarFPTaoTkt,0)

				IF ISNULL(@Cd_IMPLANTE,'') = ''
				BEGIN
					SET @CD_IMPLANTE = '0' 
				END 
	
				CREATE TABLE #TablaReservas(Id INT IDENTITY,Id_ReservasGDS INT, id_ReservaGDS_Detalles INT, ds_ItinerarioAerolinea VARCHAR(128)) 
				EXEC dbo.spza_Get_GDSFacturacionAutoJOB_ItinerarioAerolinea 
					@id_usuario		= @id_usuario,
					@cd_sucursal	= @cd_sucursal,
					@cd_implante	= @cd_implante 

					

				SELECT * FROM (
				--Tiquetes.
				SELECT PNR, Tipo, ISNULL(Servicio,'') AS 'Servicio', Descrip, id, iden_gds, ds_fecha, cd_tiqueteador, cd_vendedor, cd_cliente, am_highfare, am_lowfare, am_fare, ds_reasoncode, ISNULL(ds_cliname,'') AS 'ds_cliname', ISNULL(ds_clidir,'') AS 'ds_clidir', ISNULL(ds_clicity,'') AS 'ds_clicity', ISNULL(ds_cliid,'') AS 'ds_cliid'
						,	LEFT(CASE WHEN iden_gds = 2 then Servicio    
								WHEN isnull(rtrim(ds_itinerario),'') <> '' AND dbo.fnza_get_ReservasGDSNumeroTKts(id)>1 then ds_itinerario 
								ELSE dbo.fnza_Get_ReservaItinerarioSobrante (Id,id_air) end,63) AS 'ds_itinerario' --rgelis 2019/12/10 req.105901
						, ds_clases, in_nacionalidad, id_air, ds_pax_number, ds_pax_firstnm, ds_pax_lastnm, ds_pax_prefix, ds_tkt_number, ds_tkt_prefix, ds_aero_code, ds_moneda, am_tarifa, am_iva, ISNULL(am_tua,0) AS 'am_tua', ISNULL(am_comb,0) AS 'am_comb', CASE WHEN ISNULL(am_tua,0)>=0 AND ISNULL(am_comb,0)>=0 AND ISNULL(am_vat,0)>=0 THEN (ISNULL(am_vat,0)-(ISNULL(am_comb,0)+ISNULL(am_tua,0))) ELSE ISNULL(am_vat,0) END AS 'am_vat', ds_cc_code, ds_cc_number
						,CASE WHEN ISNULL(bl_ExentoIva,0)<>0 THEN ISNULL(am_tao,0)+ISNULL(am_ivatao,0) ELSE ISNULL(am_tao,0) END am_tao
						,CASE WHEN ISNULL(bl_ExentoIva,0)<>0 THEN 0 ELSE ISNULL(am_ivatao,0) END AS am_ivatao
						, ISNULL(am_cap,0) AS 'am_cap', ISNULL(am_ivacap,0) AS 'am_ivacap', ds_cc_code2, ds_cc_number2, am_fp1, am_fp2, cd_tktrevisado, am_TarifaContado, am_IvaContado, am_OtrosContado, am_TarifaCredito, am_IvaCredito, am_OtrosCredito, am_Comision, cd_clitipodoc, cd_clitipotercero, ds_clirazoncial, ds_cliname2, ds_clilastname, ds_clilastname2, cd_clipais, ds_clitel, cd_TipoTransaccion, ISNULL(Fecha_Salida,GETDATE()) AS 'Fecha_Salida', ISNULL(Fecha_Llegada,GETDATE()) AS 'Fecha_Llegada', Id_Srv, CASE WHEN Tipo = 'Aire' THEN in_nacionalidad WHEN Tipo='Srv' AND ISNULL(cd_conceptofacturacion,'')<>'' THEN (SELECT top 1 id FROM dbo.ConceptoFacturacion WHERE cd_codigo=cd_conceptofacturacion) ELSE cd_conceptofacturacion END AS 'cd_conceptofacturacion', cd_tiposervicio, cd_proveedores, ds_proveedores, id_car, dt_entrega, in_cars, cd_carcode, cd_conf_car, cd_citysalida, dt_retorno, cd_cartype, cd_currency, am_tarifacar, cd_bookingsource, cd_ratecode, id_htl, dt_checkin, in_guests, cd_confirmation, cd_city, cd_htlchain, dt_checkout, in_noches, ds_htlname, in_habs, cd_bed, cd_ratecode_htl, cd_htlcur, am_htltarifa, cd_agcur, am_agtarifa, ds_dir1, ds_tel, ds_fax, cd_centrocosto, NumTktConj, Respuesta, ds_solicita, cd_pax_CC, ds_lapsoviaje, ds_archivo, ds_Observaciones, ds_ClienteEmail, cd_sucursal, cd_implante, bl_ClienteActualizar, bl_NotificacionMPD, cd_FormaPagoTAO, cd_TarjetaCreditoTAO, case when LEN(ISNULL(cd_NumeroTarjetaTAO,''))>5 AND ISNULL(@cd_TCTipoTarjetaMostrarNumero,'')<>ISNULL(cd_TarjetaCreditoTAO,'') then ISNULL(RIGHT(cd_NumeroTarjetaTAO,4),'') else Isnull(cd_NumeroTarjetaTAO,'') end AS cd_NumeroTarjetaTAO , cd_VencimientoTarjetaTAO, cd_NumeroPolizaTAO, cd_AnexoPolizaTAO, am_PorDesFormaPagoTA, cd_Penalidad, ds_cc_vence, ds_cc_vence2, ds_cc_autorizacion, ds_cc_autorizacion2, ds_cc_voucher, ds_cc_voucher2, ds_AutorizacionTarjetaTAO, ds_VoucherTarjetaTAO, am_fptao, in_cc_cuotas, in_cc_cuotas2, in_cuotasTarjetaTAO, cd_TipoTarifaTAO, cd_TipoTiquete, am_TasaCambio, cd_tiqueteador_facturador, bl_ahorro, in_CantidadTarifaTAO, in_CantidadSegmentoTAO, cd_tourcode, ds_contrato, cd_PasaportePax, ds_itinerarioaerolinea, ds_tkt_prefixIata, ds_Evento, cd_iata, ds_aero_codeIata, ReservaFactura, cd_Ahorro, cd_Categoria, Id_FormasPagoAirPlus, cd_FormasPagoAirPlus, ds_FormasPagoAirPlus, cd_TarjetasCreditoAirPlus, ds_numerotarjetaAirPlus, am_PorFacParcial, am_PorFacParcial_Utilizar, in_cantpax, Id_Precompra, id_sucursal, bl_cotizacion, cd_htl, CASE WHEN ISNULL(id_FormasPago,0)=0 AND ISNULL(ds_cc_code,'')='' THEN 1 WHEN ISNULL(id_FormasPago,0)=0 AND ISNULL(ds_cc_code,'')<>'' THEN 2 ELSE id_FormasPago END AS 'id_FormasPago', CASE WHEN ISNULL(id_TarjetasCredito,0)=0 THEN (SELECT id FROM dbo.TarjetasCredito WHERE cd_codigo=ds_cc_code) ELSE id_TarjetasCredito END AS 'id_TarjetasCredito'
						, id_formapago_cliente, cd_formapago_cliente, ds_formapago_cliente,cd_fp_OtrosItems, cd_auxiliar, cd_tipoventa,am_iva2,cd_licitacion, ds_descripcion, id_tipoproveedor, cd_tipoproveedor, ds_tipoproveedor, cd_Consecutivo_variablesadicionales, cd_item	
				FROM (
					SELECT DISTINCT
						PNR = r.cd_codigo,
						'Aire' 			AS 'Tipo',
						r.ds_itinerario AS 'Servicio',
						'Tkt ' + tkt.ds_tkt_number + ' - ' + tkt.ds_pax_lastnm + ' ' + tkt.ds_pax_firstnm AS 'Descrip',
					
						r.id,
						r.iden_gds,	
						r.ds_fecha,
						CASE 
								WHEN Sucursales.bl_usartiqueteador = 1 AND Sucursales.id_tiqueteador IS NOT NULL THEN Tiqueteadores.cd_codigo
								WHEN Sucursales.bl_usarfacturador = 1 THEN r.cd_vendedor
								WHEN @bl_TomarSucursalImplantePCCGDS = 1 AND r.pcc_emite <> '' AND ISNULL(r.PCC,'') <> ISNULL(r.PCC_Emite,'') AND pcc_emite.id IS NULL THEN r.cd_vendedor
								ELSE r.cd_tiqueteador 
							END AS 'cd_tiqueteador',
						CASE 
								WHEN @bl_tomarvendedorcliente=1 THEN ISNULL(c.IDVENDE,'') 
								ELSE r.cd_vendedor 
							END AS 'cd_vendedor',	/*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
						r.cd_cliente,
						r.am_highfare,
						r.am_lowfare,
						r.am_fare,
						r.ds_reasoncode,
						ds_cliname = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_cliname,''))) = '' THEN ISNULL(c.razoncial, '') ELSE r.ds_cliname END,
						ds_clidir = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_clidir,''))) = '' THEN ISNULL(c.Direccion, '') ELSE r.ds_clidir END,
						ds_clicity = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_clicity,''))) = '' THEN ISNULL(c.ciudad, '') ELSE r.ds_clicity END,
						r.ds_cliid,
						case when r.iden_gds = 2 then r.ds_itinerario    
							 when isnull(rtrim(tkt.ds_itinerario),'') <> '' AND dbo.fnza_get_ReservasGDSNumeroTKts(r.id)>1 then tkt.ds_itinerario 
							 else dbo.fnza_Get_ReservaItinerarioSobrante (r.Id,tkt.Id) end AS 'ds_itinerario',
						r.ds_clases,
						--r.in_nacionalidad,
						in_nacionalidad= CASE WHEN @bl_tomarnacionalidadDetalles = 1 AND TKT.in_nacionalidad IS NOT NULL THEN TKT.in_nacionalidad 
											  WHEN @bl_EMD= 'S' 
													AND TKT.ds_aero_code IN  (SELECT entidad FROM @TAerolineas)
													AND ((R.iden_gds=2 AND (TKT.cd_Penalidad IS NOT NULL AND RTRIM(TKT.cd_Penalidad) <> ''))
														  OR (R.iden_gds = 1 AND TKT.cd_TipoTiquete = @cd_TipoDocEMD)
														)
											  THEN @nacionalidad_EMD
										      ELSE r.in_nacionalidad END,	
						tkt.id AS 'id_air',
						tkt.ds_pax_number,
						tkt.ds_pax_firstnm,
						tkt.ds_pax_lastnm,
						tkt.ds_pax_prefix,
						tkt.ds_tkt_number,
						tkt.ds_tkt_prefix,
						tkt.ds_aero_code,
						tkt.ds_moneda,
						tkt.am_tarifa,
						tkt.am_iva,
						tkt.am_tua,
						tkt.am_comb,
						tkt.am_vat,
						tkt.ds_cc_code AS 'ds_cc_code',
						CASE WHEN A.id IS NOT NULL THEN A.Numero ELSE tkt.ds_cc_number END AS 'ds_cc_number',
						CASE WHEN ISNULL(CR.bl_ExentoIva,0)<>0 THEN ISNULL(tkt.am_tao,0)+ISNULL(tkt.am_ivatao,0) ELSE ISNULL(tkt.am_tao,0) END am_tao,
						CASE WHEN ISNULL(CR.bl_ExentoIva,0)<>0 THEN 0 ELSE ISNULL(tkt.am_ivatao,0) END AS am_ivatao,
						tkt.am_cap,
						tkt.am_ivacap,
						tkt.ds_cc_code2,
						tkt.ds_cc_number2,
						tkt.am_fp1,
						tkt.am_fp2,
						RTRIM(tkt.cd_tktrevisado) AS 'cd_tktrevisado',
					
						tkt.am_TarifaContado,
						tkt.am_IvaContado,
						tkt.am_OtrosContado,
						tkt.am_TarifaCredito,
						tkt.am_IvaCredito,
						tkt.am_OtrosCredito,
						tkt.am_Comision ,
					
								
						cd_clitipodoc, 
						cd_clitipotercero, 
						ds_clirazoncial, 
						ds_cliname2, 
						ds_clilastname, 
						ds_clilastname2, 
						cd_clipais, 
						ds_clitel = CASE WHEN LTRIM(RTRIM(ISNULL(ds_clitel,''))) = '' THEN ISNULL(c.telefono, '') ELSE ds_clitel END,
						cd_TipoTransaccion = CASE WHEN @bl_BSP=1 OR r.cd_TipoTransaccion IN ('A','B') THEN '1' ELSE r.cd_TipoTransaccion END,
						Fecha_Salida = dbo.fnza_ReservaGdsHora (r.id,LEFT(r.ds_itinerario,3),1,0),
						Fecha_Llegada =dbo.fnza_ReservaGdsHora (r.id,LEFT(r.ds_itinerario,3),0,1),

						NULL AS 'Id_Srv',
						NULL AS cd_conceptofacturacion,
						NULL AS cd_tiposervicio,
						NULL AS cd_proveedores,
						NULL AS ds_proveedores,

						NULL AS 'id_car',
						NULL AS dt_entrega,
						NULL AS in_cars,
						NULL AS cd_carcode,
						NULL AS cd_conf_car,
						NULL AS cd_citysalida,
						NULL AS dt_retorno,
						NULL AS cd_cartype,
						NULL AS cd_currency,
						NULL AS am_tarifacar,
						NULL AS cd_bookingsource,
						NULL AS cd_ratecode,
					
						NULL AS 'id_htl',
						NULL AS dt_checkin,
						NULL AS in_guests,
						NULL AS cd_confirmation,
						NULL AS cd_city,
						NULL AS cd_htlchain,
						NULL AS dt_checkout,
						NULL AS in_noches,
						NULL AS ds_htlname,
						NULL AS in_habs,
						NULL AS cd_bed,
						NULL AS cd_ratecode_htl,
						NULL AS cd_htlcur,
						NULL AS am_htltarifa,
						NULL AS cd_agcur,
						NULL AS am_agtarifa,
						NULL AS ds_dir1,
						NULL AS ds_tel,
						NULL AS ds_fax,
						CASE WHEN ISNULL(v.cd_DepartCliente,'')<>'' THEN v.cd_DepartCliente ELSE r.cd_centrocosto END AS 'cd_centrocosto', --inicio rgelis 2016/09/15 req.33812
						CASE WHEN r.iden_gds = 1 AND tkt.NumTktConj>0 THEN tkt.NumTktConj-1 ELSE tkt.NumTktConj END AS 'NumTktConj', /*rgelis 2014/12/23 req....... numero de tiquetes en conjuncion -EVT*/
						'' 	 AS 'Respuesta',
						r.ds_solicita,
						Tkt.cd_pax_CC,
						Tkt.ds_lapsoviaje,
						FPA.ds_archivo,
						r.ds_Observaciones,	/*inicio rgelis 2014/03/28 req.15175*/
						ds_ClienteEmail = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_ClienteEmail,''))) = '' THEN ISNULL(c.email, '') ELSE r.ds_ClienteEmail END,
						r.cd_sucursal,
						r.cd_implante,
						r.bl_ClienteActualizar,
						CONVERT(INT,tkt.bl_NotificacionMPD) AS 'bl_NotificacionMPD', --rgelis correcion porque en la grilla siempre coloca verdadero
						CASE WHEN @TomarTC_Voucher_Auto_ZeusTC = 1 AND A.id IS NOT NULL AND A.ReversionTA IS NULL  THEN 'TC'
							 WHEN ISNULL(tkt.cd_FormaPagoTAO,'')<>'' THEN LTRIM(RTRIM(tkt.cd_FormaPagoTAO))
							 WHEN ISNULL(tkt.ds_cc_code,'')<>'' AND A.id IS NOT NULL AND A.ReversionTA IS NULL THEN 'TC' 
							 ELSE LTRIM(RTRIM(tkt.cd_FormaPagoTAO)) END AS 'cd_FormaPagoTAO',
						CASE WHEN A.id IS NOT NULL THEN A.CdTipoTarjeta ELSE tkt.cd_TarjetaCreditoTAO END AS 'cd_TarjetaCreditoTAO',
						CASE WHEN A.id IS NOT NULL THEN A.Numero ELSE tkt.cd_NumeroTarjetaTAO END AS 'cd_NumeroTarjetaTAO',
						tkt.cd_VencimientoTarjetaTAO,
						tkt.cd_NumeroPolizaTAO,
						tkt.cd_AnexoPolizaTAO,
						tkt.am_PorDesFormaPagoTA, /*fin rgelis 2014/03/28 req.15175*/
						ISNULL(tkt.cd_Penalidad,'') AS 'cd_Penalidad', /*rgelis 2014/07/16 req.20502*/
						ISNULL(tkt.ds_cc_vence,'') AS 'ds_cc_vence', 
						ISNULL(tkt.ds_cc_vence2,'') AS 'ds_cc_vence2',
						CASE WHEN tc.id IS NOT NULL AND RTRIM(ISNULL(tkt.ds_cc_autorizacion,''))='' THEN CONVERT(varchar(25),tkt.ds_tkt_number) --rgelis 2018/03/21 req.56941
							 WHEN @TomarTC_Voucher_Auto_ZeusTC = 1 THEN A.AutorizacionAerea 
							 WHEN ISNULL(A.AutorizacionAerea,'')<>'' THEN A.AutorizacionAerea 
							 ELSE RTRIM(ISNULL(tkt.ds_cc_autorizacion,'')) END AS 'ds_cc_autorizacion', 
						ISNULL(tkt.ds_cc_autorizacion2,'') AS 'ds_cc_autorizacion2',
						CASE WHEN tc.id IS NOT NULL AND RTRIM(ISNULL(tkt.ds_cc_voucher,''))='' THEN LEFT(tkt.ds_tkt_number,10) ELSE CASE WHEN @TomarTC_Voucher_Auto_ZeusTC = 1 THEN CONVERT(VARCHAR(10),A.VoucherAerolinea) ELSE CASE WHEN ISNULL(A.VoucherAerolinea,'') ='' then RTRIM(ISNULL(tkt.ds_cc_voucher,'')) ELSE convert(varchar,A.VoucherAerolinea) END END END AS 'ds_cc_voucher', --rgelis 2018/03/21 req.56941				
					
						ISNULL(tkt.ds_cc_voucher2,'') AS 'ds_cc_voucher2',
					
						CASE WHEN @TomarTC_Voucher_Auto_ZeusTC = 1 THEN convert(varchar,A.AutorizacionTA) ELSE CASE WHEN ISNULL(A.AutorizacionTA,'') ='' then LTRIM(RTRIM(ISNULL(tkt.ds_AutorizacionTarjetaTAO,''))) else convert(varchar,A.AutorizacionTA) END END AS 'ds_AutorizacionTarjetaTAO',
						CASE WHEN @TomarTC_Voucher_Auto_ZeusTC = 1 THEN convert(varchar,A.VoucherTA) ELSE CASE WHEN ISNULL(A.VoucherTA,'') ='' then LTRIM(RTRIM(ISNULL(tkt.ds_VoucherTarjetaTAO,''))) else convert(varchar,A.VoucherTA) END END AS 'ds_VoucherTarjetaTAO',

						ISNULL(tkt.am_fptao,0) AS 'am_fptao',
						CASE WHEN @TomarTC_Voucher_Auto_ZeusTC = 1 THEN A.NumeroCuotas ELSE ISNULL(A.NumeroCuotas,ISNULL(tkt.in_cc_cuotas,0)) END  AS 'in_cc_cuotas',
						ISNULL(tkt.in_cc_cuotas2,0) AS 'in_cc_cuotas2',
						CASE WHEN @TomarTC_Voucher_Auto_ZeusTC = 1 THEN A.NumeroCuotas ELSE ISNULL(A.NumeroCuotas,ISNULL(tkt.in_cuotasTarjetaTAO,0)) END AS 'in_cuotasTarjetaTAO',
						ISNULL(cd_TipoTarifaTAO,'') AS 'cd_TipoTarifaTAO',
						ISNULL(cd_TipoTiquete,'') AS 'cd_TipoTiquete',
						ISNULL(r.am_TasaCambio,0) AS 'am_TasaCambio', /*rgelis 2014/11/08 req.22124*/ 
						r.cd_vendedor as cd_tiqueteador_facturador,
						r.bl_ahorro,
						ISNULL(tkt.in_CantidadTarifaTAO,0) AS 'in_CantidadTarifaTAO',
						ISNULL(tkt.in_CantidadSegmentoTAO,0) AS 'in_CantidadSegmentoTAO',
						CASE WHEN ISNULL(r.cd_tourcode,'')<>'' THEN r.cd_tourcode ELSE ISNULL(tkt.cd_tourcode,'') END AS 'cd_tourcode',
						r.ds_contrato,
						tkt.cd_PasaportePax,
						ds_itinerarioaerolinea= CASE WHEN ISNULL(tr.ds_ItinerarioAerolinea,'') = '' THEN dbo.fnza_Get_ReservasAerolineaRutas (r.id) ELSE tr.ds_ItinerarioAerolinea END,
						ds_tkt_prefixIata,
						r.ds_Evento,
						isnull(r.cd_iata,'') AS 'cd_iata',
						TKT.ds_aero_codeIata, 
						ReservaFactura = CASE WHEN @AgruparFacturasAutomaticasXCliente = 'S' AND ISNULL(r.cd_cliente,'') <> '' THEN r.cd_cliente + '-'  + CONVERT(VARCHAR,(ROW_NUMBER()   OVER(PARTITION BY r.cd_cliente ORDER BY r.cd_cliente DESC)-1) / @MaximoNumeroTktsFacturaAutomatica)
							  ELSE r.cd_codigo + (CASE WHEN @bl_GenerarFacturaXTiquete = 1 THEN SPACE (20) + convert(VARCHAR,ROW_NUMBER()   OVER(PARTITION BY r.cd_codigo ORDER BY r.cd_codigo DESC)) ELSE '' END) END,
						r.cd_Ahorro, /*rgelis 2016/09/09 req.33775*/
						CASE WHEN ISNULL(v.cd_Categoria,'')<>'' THEN v.cd_Categoria ELSE @cd_categoria END AS 'cd_Categoria', --inicio rgelis 2016/09/15 req.33812
						Case when FPTAO.Id Is Not null Then FPTAO.id 
							 when tc.Id Is Not null And cap.id Is Not Null Then cap.Id_FormasPago 
							 Else Null End As 'Id_FormasPagoAirPlus',
						Case when FPTAO.Id Is Not null Then FPTAO.cd_codigo
							 when tc.Id Is Not null And cap.id Is Not Null Then fp.cd_codigo 
							 Else Null End As 'cd_FormasPagoAirPlus',
						Case when FPTAO.Id Is Not null Then FPTAO.ds_nombre
							 when tc.Id Is Not null And cap.id Is Not Null Then fp.ds_nombre 
							 Else Null End As 'ds_FormasPagoAirPlus',
						Case when FPTAO.Id Is Not null And tctao.id Is Not Null Then tctao.cd_codigo
							 when tc.Id Is Not null And cap.id Is Not Null Then tcap.cd_codigo 
							 Else Null End As 'cd_TarjetasCreditoAirPlus',
						Case when FPTAO.Id Is Not null And tctao.id Is Not Null Then tkt.cd_NumeroTarjetaTAO
							 when tc.Id Is Not null And cap.id Is Not Null Then ds_numerotarjeta 
							 Else Null End As 'ds_numerotarjetaAirPlus',
						tkt.am_PorFacParcial, --rgelis 2017/08/24 req.51825
						CASE WHEN tkt.am_PorFacParcial > 0 AND tkt.am_PorFacParcial<100 THEN 100-tkt.am_PorFacParcial ELSE tkt.am_PorFacParcial END AS 'am_PorFacParcial_Utilizar',-- rgelis 2017/09/14 req.51825
						tkt.in_cantpax, --rgelis 2017/08/24 req.35871
						Id_Precompra = dbo.fnza_Get_PrecompraPorTiquete (NULL,r.ds_fecha,tkt.ds_aero_code),
						id_sucursal = sp.id, --rgelis 2018/03/13 req.52081
						bl_cotizacion=0, --rgelis 2018/04/09 req.56942
						cd_htl=NULL, --rgelis 2018/04/09 req.56942
						tkt.id_FormasPago,  --rgelis 2018/11/19 req.74409
						tkt.id_TarjetasCredito, --rgelis 2018/11/19 req.74409
						id_formapago_cliente=FPC.id,  --rgelis 2019/01/24 req.75925
						cd_formapago_cliente=FPC.cd_codigo, --rgelis 2019/01/24 req.75925
						ds_formapago_cliente=FPC.ds_nombre, --rgelis 2019/01/24 req.75925
						R.cd_fp_OtrosItems,
						cd_auxiliar = '',
						r.cd_tipoventa
						,tkt.am_iva2
						,r.cd_licitacion
						,cr.bl_ExentoIva
						,ds_descripcion = ISNULL(r.ds_descripcion,'')
						,id_tipoproveedor=0
						,cd_tipoproveedor = ''
						,ds_tipoproveedor = ''
						,cd_Consecutivo_variablesadicionales=NULL
						,cd_item = ''
					FROM dbo.ReservasGDS r
					INNER JOIN dbo.ReservaGDS_Detalles tkt ON (r.id=tkt.id_reserva)
					LEFT JOIN #TablaReservas tr ON (tr.Id_ReservasGDS=tkt.id_reserva AND tr.id_ReservaGDS_Detalles=tkt.id)/* rgelis 2013/07/18 req.15537 */
					INNER JOIN (
									SELECT DISTINCT top 50  rfa.cd_sucursal,rfa.cd_implante,rfa.id_reserva,rfa.ds_Archivo 
									from dbo.ReservasGDS_FacAuto rfa 
									inner join ReservaGDS_Detalles rd on rd.id_reserva = rfa.id_reserva
									inner join dbo.ReservasGDS r on r.id = rfa.id_reserva
									LEFT JOIN CLIENTES c ON (c.IDCLIENTE = R.cd_cliente OR c.IDCLIENTE= r.ds_cliid) /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
									LEFT JOIN dbo.ConfiguracionClientesFacAuto cc ON cc.cd_codigo = c.IDCLIENTE --rgelis 2018/04/13 req.58321
									where rd.bl_usada=0 and rd.bl_anulado = 0
									AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_sucursal, ',', 0, 1) s WHERE s.Codigo = rfa.cd_sucursal) OR ISNULL(@cd_sucursal,'')='' OR @FiltrarSucursalFactAuto = 0)
									AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_implante, ',', 0, 1) i WHERE i.Codigo = ISNULL(rfa.cd_implante,'0')) OR ISNULL(@cd_implante,'')='' OR @FiltrarImplanteFactAuto = 0)
									AND (cc.id IS NOT NULL OR @SoloUtilizarConfgClienteFacAuto=0)
								)fpa ON fpa.id_reserva = r.id
					LEFT JOIN CLIENTES c ON (c.IDCLIENTE = R.cd_cliente OR c.IDCLIENTE= r.ds_cliid) /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
					--LEFT JOIN Configuracion_remisiones CR ON (CR.ID_CLIENTE = C.IDCLIENTE OR C.IDCLIENTE = R.ds_cliid)
					LEFT JOIN Configuracion_remisiones CR ON (CR.ID_CLIENTE = C.IDCLIENTE)
					LEFT JOIN dbo.Sucursales ON Sucursales.cd_codigo = r.cd_sucursal
					LEFT JOIN dbo.Tiqueteadores ON Tiqueteadores.id = Sucursales.id_tiqueteador
					LEFT JOIN dbo.Implantes pcc_emite ON pcc_emite.cd_codigo = r.pcc_emite
					OUTER APPLY dbo.fnza_ZeusTc_Autorizaciones(r.cd_codigo) AS A
					OUTER APPLY dbo.fnza_GetCategoriaVariableGDSTable(r.cd_codigo) AS v
					LEFT JOIN dbo.tarjetascredito tc on tc.cd_codigo = tkt.ds_cc_code AND (tc.bl_airplus = 1 OR @bl_tomarFPAirplusTkt=1)
					LEFT JOIN dbo.Cliente_FP_AirPlus cap on cap.id_cliente = c.idcliente
					LEFT JOIN dbo.FormasPago fp on fp.id = cap.Id_FormasPago
					LEFT JOIN dbo.tarjetascredito tcap on tcap.id=cap.Id_TarjetasCredito
					LEFT JOIN dbo.Sucursales SP ON (SP.cd_codigo = tkt.cd_PSeudo OR SP.cd_alterno=tkt.cd_PSeudo) --rgelis 2018/03/13 req.50281
					LEFT JOIN dbo.ConfiguracionClientesFacAuto cc ON cc.cd_codigo = c.IDCLIENTE --rgelis 2018/04/13 req.58321
					LEFT JOIN dbo.FormasPago FPC ON FPC.cd_codigo = r.cd_formapago_cliente--rgelis 2019/01/24 req.75925
					LEFT JOIN dbo.FormasPago FPTAO ON FPTAO.cd_codigo=Tkt.cd_FormaPagoTAO AND @bl_tomarFPTaoTkt=1 
					LEFT JOIN dbo.tarjetascredito tctao on tctao.cd_codigo=tkt.cd_TarjetaCreditoTAO
					WHERE tkt.bl_usada = 0
					AND tkt.bl_anulado = 0 --rgelis 2018/08/29 Ticket.34953				
					AND (bl_NoFacturarAutomaticamente = 0 OR CR.ID IS NULL)
					AND (cc.id IS NOT NULL OR @SoloUtilizarConfgClienteFacAuto=0) --rgelis 2018/04/13 req.58321
					AND @bl_factura = 1
					AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_sucursal, ',', 0, 1) s WHERE s.Codigo = fpa.cd_sucursal) OR ISNULL(@cd_sucursal,'')='')
					AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_implante, ',', 0, 1) i WHERE i.Codigo = ISNULL(fpa.cd_implante,'0')) OR ISNULL(@cd_implante,'')='' OR @cd_implante='0')
				) AS Itinerario
				INNER JOIN (Select DISTINCT 
							Id_Reserva_ReservaGDS_Itinerarios =  ReservaGDS_Itinerarios.Id_Reserva 
							From ReservasGDS
							INNER JOIN dbo.ReservaGDS_Detalles ON ReservaGDS_Detalles.id_reserva = ReservasGDS.id
							INNER JOIN ReservaGDS_Itinerarios ON ReservaGDS_Itinerarios.Id_Reserva = ReservasGDS.Id
							WHERE ReservaGDS_Detalles.bl_usada = 0 AND ReservaGDS_Detalles.bl_anulado = 0 
							) RI ON ri.Id_Reserva_ReservaGDS_Itinerarios = ID
				--				Where Id IN (Select DISTINCT Id_Reserva From ReservaGDS_Itinerarios)

				UNION ALL

				--Servicios Car.
				SELECT distinct
					rtrim(r.cd_codigo)	AS 'PNR',
					'Auto' 			AS 'Tipo',
					car.cd_cartype	AS 'Servicio',
					'Desde ' + Convert(VARCHAR(19),car.dt_entrega) + ' hasta ' + Convert(VARCHAR(19),car.dt_retorno)  AS 'Descrip',
					
					r.id,
					r.iden_gds,	
					r.ds_fecha,
					r.cd_tiqueteador,
					CASE WHEN @bl_tomarvendedorcliente=1 THEN ISNULL(c.IDVENDE,'') ELSE r.cd_vendedor END AS 'cd_vendedor',	/*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
					r.cd_cliente,
					r.am_highfare,
					r.am_lowfare,
					r.am_fare,
					r.ds_reasoncode,
					ds_cliname = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_cliname,''))) = '' THEN ISNULL(c.razoncial, '') ELSE r.ds_cliname END,
					ds_clidir = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_clidir,''))) = '' THEN ISNULL(c.Direccion, '') ELSE r.ds_clidir END,
					ds_clicity = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_clicity,''))) = '' THEN ISNULL(c.ciudad, '') ELSE r.ds_clicity END,
					ds_cliid = CASE WHEN ISNULL(r.ds_cliid,'')='' AND ISNULL(r.cd_cliente,'')<>'' THEN r.cd_cliente ELSE r.ds_cliid END,
					r.ds_itinerario,
					r.ds_clases,
					in_nacionalidad=CASE WHEN ISNULL(srv.in_nacionalidad,0)<>0 THEN srv.in_nacionalidad 
										 WHEN ISNULL(r.in_nacionalidad,0)=0 THEN 1 ELSE r.in_nacionalidad END,

					NULL AS 'id_air',
					srv.ds_pax_number AS ds_pax_number,
					srv.ds_pax_firstnm AS ds_pax_firstnm,
					srv.ds_pax_lastnm AS ds_pax_lastnm,
					srv.ds_pax_prefix AS ds_pax_prefix,
					NULL AS ds_tkt_number,
					NULL AS ds_tkt_prefix,
					NULL AS ds_aero_code,
					NULL AS ds_moneda,
					srv.am_tarifa AS am_tarifa,
					srv.am_iva AS am_iva,
					NULL AS am_tua,
					NULL AS am_comb,
					srv.am_vat AS am_vat,
					srv.ds_cc_code AS ds_cc_code,
					srv.ds_cc_number AS ds_cc_number,
					NULL AS am_tao,
					NULL AS am_ivatao,
					NULL AS am_cap,
					NULL AS am_ivacap,
					srv.ds_cc_code AS ds_cc_code2,
					srv.ds_cc_number2 AS ds_cc_number2,
					srv.am_fp1 AS am_fp1,
					srv.am_fp2 AS am_fp2,
					NULL AS cd_tktrevisado,
					
					srv.am_TarifaContado AS am_TarifaContado,
					srv.am_IvaContado AS am_IvaContado,
					srv.am_OtrosContado AS am_OtrosContado,
					srv.am_TarifaCredito AS am_TarifaCredito,
					srv.am_IvaCredito AS am_IvaCredito,
					srv.am_OtrosCredito AS am_OtrosCredito,
					srv.am_Comision AS am_Comision,
					
								
					cd_clitipodoc, 
					cd_clitipotercero, 
					ds_clirazoncial, 
					ds_cliname2, 
					ds_clilastname, 
					ds_clilastname2, 
					cd_clipais, 
					ds_clitel = CASE WHEN LTRIM(RTRIM(ISNULL(ds_clitel,''))) = '' THEN ISNULL(c.telefono, '') ELSE ds_clitel END,
					cd_TipoTransaccion = CASE WHEN @bl_BSP=1 OR r.cd_TipoTransaccion IN ('A','B') THEN '1' ELSE r.cd_TipoTransaccion END,
					NULL AS 'Fecha_Salida',
					NULL AS 'Fecha_Llegada',

					srv.id AS 'Id_Srv',
					NULL AS cd_conceptofacturacion,
					NULL AS cd_tiposervicio,
					ISNULL(srv.cd_proveedores,'') AS cd_proveedores,
					ISNULL(p.RAZONCIAL,'') AS ds_proveedores,

					car.id AS 'id_car',
					car.dt_entrega,
					car.in_cars,
					car.cd_carcode,
					car.cd_confirmation AS 'cd_conf_car',
					car.cd_citysalida,
					car.dt_retorno,
					car.cd_cartype,
					car.cd_currency,
					car.am_tarifa AS 'am_tarifacar',
					car.cd_bookingsource,
					car.cd_ratecode,
					
					NULL AS 'id_htl',
					NULL AS dt_checkin,
					NULL AS in_guests,
					NULL AS cd_confirmation,
					NULL AS cd_city,
					NULL AS cd_htlchain,
					NULL AS dt_checkout,
					NULL AS in_noches,
					NULL AS ds_htlname,
					NULL AS in_habs,
					NULL AS cd_bed,
					NULL AS cd_ratecode_htl,
					NULL AS cd_htlcur,
					NULL AS am_htltarifa,
					NULL AS cd_agcur,
					NULL AS am_agtarifa,
					NULL AS ds_dir1,
					NULL AS ds_tel,
					NULL AS ds_fax,
					CASE WHEN ISNULL(v.cd_DepartCliente,'')<>'' THEN v.cd_DepartCliente ELSE r.cd_centrocosto END AS 'cd_centrocosto',		
					0 as NumTktConj,
					'' 	 AS 'Respuesta',
					r.ds_solicita,
					srv.cd_paxidentificacion as 'cd_pax_CC',
					'' as 'ds_lapsoviaje',
					FPA.ds_archivo,
					r.ds_Observaciones, 
					ds_ClienteEmail = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_ClienteEmail,''))) = '' THEN ISNULL(c.email, '') ELSE r.ds_ClienteEmail END,
					r.cd_sucursal,
					r.cd_implante,
					bl_ClienteActualizar=0,
					bl_NotificacionMPD=0,
					cd_FormaPagoTAO='',
					cd_TarjetaCreditoTAO='',
					cd_NumeroTarjetaTAO='',
					cd_VencimientoTarjetaTAO='',
					cd_NumeroPolizaTAO='',
					cd_AnexoPolizaTAO='',
					am_PorDesFormaPagoTA=0, 
					cd_Penalidad='', 
					ds_cc_vence = '', 
					ds_cc_vence2 = '',
					ds_cc_autorizacion = '',
					ds_cc_autorizacion2 = '',
					ds_cc_voucher = '',
					ds_cc_voucher2 = '',
					ds_AutorizacionTarjetaTAO = '',
					ds_VoucherTarjetaTAO = '',
					am_fptao = 0,
					in_cc_cuotas = 0,
					in_cc_cuotas2 = 0,
					in_cuotasTarjetaTAO = 0,
					cd_TipoTarifaTAO = '',
					cd_TipoTiquete = '',
					ISNULL(r.am_TasaCambio,0) AS 'am_TasaCambio',  
					r.cd_vendedor as cd_tiqueteador_facturador,
					r.bl_ahorro,
					in_CantidadTarifaTAO=0,
					in_CantidadSegmentoTAO=0,
					cd_tourcode='',
					r.ds_contrato,
					cd_PasaportePax='',
					ds_itinerarioaerolinea='',
					ds_tkt_prefixIata='',
					r.ds_Evento,
					isnull(r.cd_iata,'') AS 'cd_iata',
					ds_aero_codeIata='', 
					ReservaFactura = r.cd_codigo+'-C',
					r.cd_Ahorro,
					CASE WHEN ISNULL(v.cd_Categoria,'')<>'' THEN v.cd_Categoria ELSE @cd_categoria END AS 'cd_Categoria', 
					Id_FormasPagoAirPlus=NULL,
					cd_FormasPagoAirPlus='',
					ds_FormasPagoAirPlus='',
					cd_TarjetasCreditoAirPlus='',
					ds_numerotarjetaAirPlus='',
					am_PorFacParcial=100, 
					am_PorFacParcial_Utilizar=100,
					in_cantpax = 1,
					Id_Precompra = NULL, 
					id_sucursal = NULL, 
					bl_cotizacion=1, --rgelis 2018/04/09 req.56942
					cd_htl=NULL, --rgelis 2018/04/09 req.56942
					id_FormasPago = NULL,  --rgelis 2018/11/19 req.74409
					id_TarjetasCredito = NULL, --rgelis 2018/11/19 req.74409
					id_formapago_cliente=FPC.id,  --rgelis 2019/01/24 req.75925
					cd_formapago_cliente=FPC.cd_codigo, --rgelis 2019/01/24 req.75925
					ds_formapago_cliente=FPC.ds_nombre, --rgelis 2019/01/24 req.75925
					R.cd_fp_OtrosItems,
					srv.cd_auxiliar,
					r.cd_tipoventa
					,am_iva2=0
					,r.cd_licitacion
					,ds_descripcion=ISNULL(r.ds_descripcion,'')
					,id_tipoproveedor=ISNULL(TP.id,0)
					,cd_tipoproveedor=ISNULL(srv.cd_tipoproveedor,'')
					,ds_tipoproveedor=ISNULL(srv.ds_tipoproveedor,'')
					,cd_Consecutivo_variablesadicionales=NULL
					,cd_item = ''
				FROM dbo.ReservasGDS r
				INNER JOIN dbo.ReservaGDS_Servicios srv ON r.id=srv.id_reserva 				 
				INNER JOIN dbo.ReservaGDS_CAR car ON (car.id_reserva = r.id AND car.ds_indice=srv.ds_indice)	 
				INNER JOIN (
								
								SELECT DISTINCT top 100  rfa.cd_sucursal,rfa.cd_implante,rfa.id_reserva,rfa.ds_Archivo 
								from dbo.ReservasGDS_FacAuto rfa 
								inner join dbo.ReservasGDS r on r.id = rfa.id_reserva
								INNER JOIN dbo.ReservaGDS_Servicios srv ON r.id=srv.id_reserva 				 
								INNER JOIN dbo.ReservaGDS_CAR car ON (car.id_reserva = r.id AND car.ds_indice=srv.ds_indice)	 
								LEFT JOIN CLIENTES c ON (c.IDCLIENTE = R.cd_cliente OR c.IDCLIENTE= r.ds_cliid) /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
								LEFT JOIN dbo.ConfiguracionClientesFacAuto cc ON cc.cd_codigo = c.IDCLIENTE --rgelis 2018/04/13 req.58321
								INNER JOIN @TValorInterfazGDSParametro PA ON PA.id_GDS = r.iden_gds AND PA.id_sys_entidades=131 AND PA.cd_codigo_maestro = 'FacAutoSrvGDS' AND PA.ds_valor = 'SI' --rgelis 2019/10/10 req.92991
								where srv.bl_usada=0 
								AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_sucursal, ',', 0, 1) s WHERE s.Codigo = rfa.cd_sucursal) OR ISNULL(@cd_sucursal,'')='' OR @FiltrarSucursalFactAuto = 0)
								AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_implante, ',', 0, 1) i WHERE i.Codigo = ISNULL(rfa.cd_implante,'0')) OR ISNULL(@cd_implante,'')='' OR @FiltrarImplanteFactAuto = 0)
								AND (cc.id IS NOT NULL OR @SoloUtilizarConfgClienteFacAuto=0)
							)fpa ON fpa.id_reserva = r.id
				LEFT JOIN dbo.PROVEEDORES p ON p.IDPROVE = srv.cd_proveedores 
				LEFT JOIN CLIENTES c ON (c.IDCLIENTE = R.cd_cliente OR c.IDCLIENTE= r.ds_cliid) /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
				LEFT JOIN dbo.ConfiguracionClientesFacAuto cc ON cc.cd_codigo = c.IDCLIENTE --rgelis 2018/04/13 req.58321
				OUTER APPLY dbo.fnza_GetCategoriaVariableGDSTable(r.cd_codigo) AS v
				LEFT JOIN dbo.FormasPago FPC ON FPC.cd_codigo = r.cd_formapago_cliente--rgelis 2019/01/24 req.75925
				INNER JOIN @TValorInterfazGDSParametro PA ON PA.id_GDS = r.iden_gds AND PA.id_sys_entidades=131 AND PA.cd_codigo_maestro = 'FacAutoSrvGDS' AND PA.ds_valor = 'SI' --rgelis 2019/10/10 req.92991
				LEFT JOIN dbo.TipoProveedores TP ON TP.cd_codigo = srv.cd_tipoproveedor
				WHERE (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_sucursal, ',', 0, 1) s WHERE s.Codigo = fpa.cd_sucursal) OR ISNULL(@cd_sucursal,'')='')
				AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_implante, ',', 0, 1) i WHERE i.Codigo = ISNULL(fpa.cd_implante,'0')) OR ISNULL(@cd_implante,'')='' OR @cd_implante='0') /*rgelis 2014/03/28 req.15175*/
				AND (cc.id IS NOT NULL OR @SoloUtilizarConfgClienteFacAuto=0) --rgelis 2018/04/13 req.58321				 
				AND srv.bl_usada = 0
				AND @GenerarCotizacion=1
				--AND ISNULL(dbo.fnza_Get_ValorInterfazGDSParametro(r.iden_gds, 131, 'FacAutoSrvGDS', NULL),'')='SI' --rgelis 2019/09/25 req.92991

				
				UNION ALL
				--Servicios Hotel
				SELECT distinct
					rtrim(r.cd_codigo) 	AS 'PNR',
					'Hotel' 		AS 'Tipo',
					Convert(VARCHAR(2),htl.in_noches) + ' noches - ' + Convert(VARCHAR(2),htl.in_habs) + ' Habitacion(es) '  AS 'Servicio',
					htl.ds_htlname + ' - ' + 'CheckIn: ' + convert(VARCHAR(15),htl.dt_checkin)  AS 'Descrip',
					
					r.id,
					r.iden_gds,	
					r.ds_fecha,
					r.cd_tiqueteador,
					CASE WHEN @bl_tomarvendedorcliente=1 THEN ISNULL(c.IDVENDE,'') ELSE r.cd_vendedor END AS 'cd_vendedor',	/*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
					r.cd_cliente,
					r.am_highfare,
					r.am_lowfare,
					r.am_fare,
					r.ds_reasoncode,
					ds_cliname = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_cliname,''))) = '' THEN ISNULL(c.razoncial, '') ELSE r.ds_cliname END,
					ds_clidir = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_clidir,''))) = '' THEN ISNULL(c.Direccion, '') ELSE r.ds_clidir END,
					ds_clicity = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_clicity,''))) = '' THEN ISNULL(c.ciudad, '') ELSE r.ds_clicity END,
					ds_cliid = CASE WHEN ISNULL(r.ds_cliid,'')='' AND ISNULL(r.cd_cliente,'')<>'' THEN r.cd_cliente ELSE r.ds_cliid END,
					r.ds_itinerario,
					r.ds_clases,
					in_nacionalidad = CASE WHEN ISNULL(srv.in_nacionalidad,0)<>0 THEN srv.in_nacionalidad 
										   WHEN ISNULL(r.in_nacionalidad,0)=0 THEN 1 ELSE r.in_nacionalidad END,

					NULL AS 'id_air',
					srv.ds_pax_number AS ds_pax_number,
					srv.ds_pax_firstnm AS ds_pax_firstnm,
					srv.ds_pax_lastnm AS ds_pax_lastnm,
					srv.ds_pax_prefix AS ds_pax_prefix,
					NULL AS ds_tkt_number,
					NULL AS ds_tkt_prefix,
					NULL AS ds_aero_code,
					NULL AS ds_moneda,
					srv.am_tarifa AS am_tarifa,
					srv.am_iva AS am_iva,
					NULL AS am_tua,
					NULL AS am_comb,
					srv.am_vat AS am_vat,
					srv.ds_cc_code AS ds_cc_code,
					srv.ds_cc_number AS ds_cc_number,
					NULL AS am_tao,
					NULL AS am_ivatao,
					NULL AS am_cap,
					NULL AS am_ivacap,
					srv.ds_cc_code2 AS ds_cc_code2,
					srv.ds_cc_number2 AS ds_cc_number2,
					srv.am_fp1 AS am_fp1,
					srv.am_fp2 AS am_fp2,
					NULL AS cd_tktrevisado,
					
					srv.am_TarifaContado AS am_TarifaContado,
					srv.am_IvaContado AS am_IvaContado,
					srv.am_OtrosContado AS am_OtrosContado,
					srv.am_TarifaCredito AS am_TarifaCredito,
					srv.am_IvaCredito AS am_IvaCredito,
					srv.am_OtrosCredito AS am_OtrosCredito,
					srv.am_Comision AS am_Comision,
					
								
					cd_clitipodoc, 
					cd_clitipotercero, 
					ds_clirazoncial, 
					ds_cliname2, 
					ds_clilastname, 
					ds_clilastname2, 
					cd_clipais, 
					ds_clitel = CASE WHEN LTRIM(RTRIM(ISNULL(ds_clitel,''))) = '' THEN ISNULL(c.telefono, '') ELSE ds_clitel END,
					r.cd_TipoTransaccion,
					NULL AS 'Fecha_Salida',
					NULL AS 'Fecha_Llegada',

					srv.id AS 'Id_Srv',
					NULL AS cd_conceptofacturacion,
					CASE WHEN ISNULL(@bl_tomartiposervicionacionalidad,0)=1 AND ISNULL(@cd_tiposervicionacional,'')<>'' AND (CASE WHEN ISNULL(srv.in_nacionalidad,0)<>0 THEN srv.in_nacionalidad WHEN ISNULL(r.in_nacionalidad,0)=0 THEN 1 ELSE r.in_nacionalidad END)=1 THEN @cd_tiposervicionacional
						 WHEN ISNULL(@bl_tomartiposervicionacionalidad,0)=1 AND ISNULL(@cd_tiposerviciointernacional,'')<>'' AND (CASE WHEN ISNULL(srv.in_nacionalidad,0)<>0 THEN srv.in_nacionalidad WHEN ISNULL(r.in_nacionalidad,0)=0 THEN 1 ELSE r.in_nacionalidad END)=2 THEN @cd_tiposerviciointernacional
						 ELSE NULL END AS cd_tiposervicio,
					CASE WHEN ISNULL(srv.cd_proveedores,'')='' THEN ISNULL(h.cd_proveedor,'') ELSE ISNULL(srv.cd_proveedores,'') END AS cd_proveedores,
					CASE WHEN ISNULL(p.RAZONCIAL,'')='' THEN ISNULL(ph.RAZONCIAL,'') ELSE ISNULL(p.RAZONCIAL,'') END AS ds_proveedores,

					NULL AS 'id_car',
					NULL AS dt_entrega,
					NULL AS in_cars,
					NULL AS cd_carcode,
					NULL AS "cd_conf_car",
					NULL AS cd_citysalida,
					NULL AS dt_retorno,
					NULL AS cd_cartype,
					NULL AS cd_currency,
					NULL AS "am_tarifacar",
					NULL AS cd_bookingsource,
					NULL AS cd_ratecode,
					
					htl.id AS "id_htl",
					htl.dt_checkin,
					htl.in_guests,
					htl.cd_confirmation,
					htl.cd_city,
					htl.cd_htlchain,
					htl.dt_checkout,
					htl.in_noches,
					htl.ds_htlname,
					htl.in_habs,
					htl.cd_bed,
					htl.cd_ratecode AS 'cd_ratecode_htl',
					htl.cd_htlcur,
					htl.am_htltarifa,
					htl.cd_agcur,
					htl.am_agtarifa,
					htl.ds_dir1,
					htl.ds_tel,
					htl.ds_fax,
					CASE WHEN ISNULL(v.cd_DepartCliente,'')<>'' THEN v.cd_DepartCliente ELSE r.cd_centrocosto END AS 'cd_centrocosto',
					0 as NumTktConj,
					'' 	 AS 'Respuesta',
					r.ds_solicita,
					srv.cd_paxidentificacion as 'cd_pax_CC',
					'' as 'ds_lapsoviaje',
					FPA.ds_archivo,
					r.ds_Observaciones, /*inicio rgelis 2014/03/28 req.15175*/
					ds_ClienteEmail = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_ClienteEmail,''))) = '' THEN ISNULL(c.email, '') ELSE r.ds_ClienteEmail END,
					r.cd_sucursal,
					r.cd_implante,
					bl_ClienteActualizar=0,
					bl_NotificacionMPD=0,
					cd_FormaPagoTAO='',
					cd_TarjetaCreditoTAO='',
					cd_NumeroTarjetaTAO='',
					cd_VencimientoTarjetaTAO='',
					cd_NumeroPolizaTAO='',
					cd_AnexoPolizaTAO='',
					am_PorDesFormaPagoTA=0, /*fin rgelis 2014/03/20 req.15175*/
					cd_Penalidad = '', /*rgelis 2014/07/16 req.20502*/
					ds_cc_vence = '', 
					ds_cc_vence2 = '',
					ds_cc_autorizacion = '',
					ds_cc_autorizacion2 = '',
					ds_cc_voucher = '',
					ds_cc_voucher2 = '',
					ds_AutorizacionTarjetaTAO = '',
					ds_VoucherTarjetaTAO = '',
					am_fptao = 0,
					in_cc_cuotas = 0,
					in_cc_cuotas2 = 0,
					in_cuotasTarjetaTAO = 0,
					cd_TipoTarifaTAO = '',
					cd_TipoTiquete = '',
					ISNULL(r.am_TasaCambio,0) AS 'am_TasaCambio', /*rgelis 2014/11/08 req.22124*/ 
					r.cd_vendedor as cd_tiqueteador_facturador,
					r.bl_ahorro,
					in_CantidadTarifaTAO=0,
					in_CantidadSegmentoTAO=0,
					cd_tourcode='',
					r.ds_contrato,
					cd_PasaportePax='',
					ds_itinerarioaerolinea='',
					ds_tkt_prefixIata='',
					r.ds_Evento,
					isnull(r.cd_iata,'') AS 'cd_iata',
					ds_aero_codeIata='', 
					ReservaFactura = r.cd_codigo+'-C',
					r.cd_Ahorro,
					CASE WHEN ISNULL(v.cd_Categoria,'')<>'' THEN v.cd_Categoria ELSE @cd_categoria END AS 'cd_Categoria', 
					Id_FormasPagoAirPlus=NULL,
					cd_FormasPagoAirPlus='',
					ds_FormasPagoAirPlus='',
					cd_TarjetasCreditoAirPlus='',
					ds_numerotarjetaAirPlus='',
					am_PorFacParcial=100, 
					am_PorFacParcial_Utilizar=100,
					in_cantpax = 1,
					Id_Precompra = NULL,
					id_sucursal = NULL, 
					bl_cotizacion=1, --rgelis 2018/04/09 req.56942
					htl.cd_htl, --rgelis 2018/04/09 req.56942
					id_FormasPago = NULL,  --rgelis 2018/11/19 req.74409
					id_TarjetasCredito = NULL, --rgelis 2018/11/19 req.74409
					id_formapago_cliente=FPC.id,  --rgelis 2019/01/24 req.75925
					cd_formapago_cliente=FPC.cd_codigo, --rgelis 2019/01/24 req.75925
					ds_formapago_cliente=FPC.ds_nombre, --rgelis 2019/01/24 req.75925
					R.cd_fp_OtrosItems,
					srv.cd_auxiliar,
					r.cd_tipoventa

					,am_iva2=0
					,r.cd_licitacion
					,ds_descripcion=ISNULL(r.ds_descripcion,'')
					,id_tipoproveedor=ISNULL(TP.id,0)
					,cd_tipoproveedor=ISNULL(srv.cd_tipoproveedor,'')
					,ds_tipoproveedor=ISNULL(srv.ds_tipoproveedor,'')
					,cd_Consecutivo_variablesadicionales=NULL
					,cd_item = ''
				FROM dbo.ReservasGDS r
				INNER JOIN dbo.ReservaGDS_Servicios srv ON srv.id_reserva = r.id 
				INNER JOIN dbo.ReservaGDS_HTL htl ON (htl.id_reserva = r.id AND htl.ds_indice=srv.ds_indice)
				INNER JOIN (
								SELECT DISTINCT top 100  rfa.cd_sucursal,rfa.cd_implante,rfa.id_reserva,rfa.ds_Archivo 
								from dbo.ReservasGDS_FacAuto rfa 
								inner join ReservaGDS_Servicios rd on rd.id_reserva = rfa.id_reserva
								inner join dbo.ReservasGDS r on r.id = rfa.id_reserva
								LEFT JOIN CLIENTES c ON (c.IDCLIENTE = R.cd_cliente OR c.IDCLIENTE= r.ds_cliid) /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
								LEFT JOIN dbo.ConfiguracionClientesFacAuto cc ON cc.cd_codigo = c.IDCLIENTE --rgelis 2018/04/13 req.58321
								where rd.bl_usada=0 and rd.bl_anulado = 0
								AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_sucursal, ',', 0, 1) s WHERE s.Codigo = rfa.cd_sucursal) OR ISNULL(@cd_sucursal,'')='' OR @FiltrarSucursalFactAuto = 0)
								AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_implante, ',', 0, 1) i WHERE i.Codigo = ISNULL(rfa.cd_implante,'0')) OR ISNULL(@cd_implante,'')='' OR @FiltrarImplanteFactAuto = 0)
								AND (cc.id IS NOT NULL OR @SoloUtilizarConfgClienteFacAuto=0)
							)fpa ON fpa.id_reserva = r.id
				LEFT JOIN dbo.Hoteles h ON h.cd_codigo = htl.cd_htl 
				LEFT JOIN dbo.PROVEEDORES p ON p.IDPROVE = srv.cd_proveedores
				LEFT JOIN dbo.PROVEEDORES ph ON ph.IDPROVE = h.cd_proveedor 
				LEFT JOIN CLIENTES c ON (c.IDCLIENTE = R.cd_cliente OR c.IDCLIENTE= r.ds_cliid) /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
				LEFT JOIN dbo.ConfiguracionClientesFacAuto cc ON cc.cd_codigo = c.IDCLIENTE --rgelis 2018/04/13 req.58321
				OUTER APPLY dbo.fnza_GetCategoriaVariableGDSTable(r.cd_codigo) AS v
				LEFT JOIN dbo.FormasPago FPC ON FPC.cd_codigo = r.cd_formapago_cliente--rgelis 2019/01/24 req.75925
				LEFT JOIN dbo.TipoProveedores TP ON TP.cd_codigo = srv.cd_tipoproveedor
				WHERE (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_sucursal, ',', 0, 1) s WHERE s.Codigo = fpa.cd_sucursal) OR ISNULL(@cd_sucursal,'')='')
				AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_implante, ',', 0, 1) i WHERE i.Codigo = ISNULL(fpa.cd_implante,'0')) OR ISNULL(@cd_implante,'')='' OR @cd_implante='0') /*rgelis 2014/03/28 req.15175*/
				AND (cc.id IS NOT NULL OR @SoloUtilizarConfgClienteFacAuto=0) --rgelis 2018/04/13 req.58321				
				AND srv.bl_usada = 0
				AND @GenerarCotizacion=1 
				AND ISNULL(dbo.fnza_Get_ValorInterfazGDSParametro(r.iden_gds, 131, 'FacAutoSrvGDS', NULL),'')='SI' --rgelis 2019/09/25 req.92991
				
				UNION ALL
				--Servicios 
				SELECT distinct
					r.cd_codigo 	AS "PNR",
					'Srv' 			AS 'Tipo',
					ISNULL(cf.ds_nombre,'')	AS 'Servicio',
					srv.ds_descrip    AS 'Descrip',
					
					r.id,
					r.iden_gds,	
					r.ds_fecha,
					CASE 
							WHEN Sucursales.bl_usartiqueteador = 1 AND Sucursales.id_tiqueteador IS NOT NULL THEN Tiqueteadores.cd_codigo
							WHEN Sucursales.bl_usarfacturador = 1 THEN r.cd_vendedor
							WHEN @bl_TomarSucursalImplantePCCGDS = 1 AND r.pcc_emite <> '' AND ISNULL(r.PCC,'') <> ISNULL(r.PCC_Emite,'') AND pcc_emite.id IS NULL THEN r.cd_vendedor
							ELSE r.cd_tiqueteador 
						END AS 'cd_tiqueteador',
					CASE WHEN @bl_tomarvendedorcliente=1 THEN ISNULL(c.IDVENDE,'') ELSE r.cd_vendedor END AS 'cd_vendedor',	/*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
					r.cd_cliente,
					r.am_highfare,
					r.am_lowfare,
					r.am_fare,
					r.ds_reasoncode,
					CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_cliname,''))) = '' THEN ISNULL(c.razoncial, '') ELSE r.ds_cliname END AS 'ds_cliname',
					CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_clidir,''))) = '' THEN ISNULL(c.Direccion, '') ELSE r.ds_clidir END AS 'ds_clidir',
					CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_clicity,''))) = '' THEN ISNULL(c.ciudad, '') ELSE r.ds_clicity END AS 'ds_clicity',
					ISNULL(r.ds_cliid,'')	AS 'ds_cliid',
					r.ds_itinerario,
					r.ds_clases,
					in_nacionalidad = CASE WHEN ISNULL(srv.in_nacionalidad,0)<>0 THEN srv.in_nacionalidad 
										   WHEN ISNULL(r.in_nacionalidad,0)=0 THEN 1 ELSE r.in_nacionalidad END,
					
					NULL AS 'id_air',
					srv.ds_pax_number,
					srv.ds_pax_firstnm,
					srv.ds_pax_lastnm,
					srv.ds_pax_prefix,
					NULL AS ds_tkt_number,
					NULL AS ds_tkt_prefix,
					NULL AS ds_aero_code,
					srv.ds_moneda,
					srv.am_tarifa,
					srv.am_iva,
					NULL AS am_tua,
					NULL AS am_comb,
					srv.am_vat,
					srv.ds_cc_code,
					srv.ds_cc_number,
					NULL AS am_tao,
					NULL AS am_ivatao,
					NULL AS am_cap,
					NULL AS am_ivacap,
					srv.ds_cc_code2,
					srv.ds_cc_number2,
					srv.am_fp1,
					srv.am_fp2,
					NULL AS 'cd_tktrevisado',
					
					srv.am_TarifaContado,
					srv.am_IvaContado,
					srv.am_OtrosContado,
					srv.am_TarifaCredito,
					srv.am_IvaCredito,
					srv.am_OtrosCredito,
					srv.am_Comision, 
					
								
					cd_clitipodoc=replace(cd_clitipodoc,char(9),''), 
					cd_clitipotercero=replace(cd_clitipotercero,char(9),''), 
					ds_clirazoncial=replace(ds_clirazoncial,char(9),''), 
					ds_cliname2=replace(ds_cliname2,char(9),''), 
					ds_clilastname=replace(ds_clilastname,char(9),''), 
					ds_clilastname2=replace(ds_clilastname2,char(9),''), 
					cd_clipais, 
					ds_clitel = CASE WHEN LTRIM(RTRIM(ISNULL(ds_clitel,''))) = '' THEN ISNULL(c.telefono, '') ELSE ds_clitel END,
					cd_TipoTransaccion = CASE WHEN @bl_BSP=1 OR r.cd_TipoTransaccion IN ('A','B') THEN '1' ELSE r.cd_TipoTransaccion END,
					NULL AS 'Fecha_Salida',
					NULL AS 'Fecha_Llegada',

					srv.id AS 'Id_Srv',
					CASE WHEN ISNULL(srv.cd_conceptofacturacion,'')='' THEN (SELECT RTRIM(Valor) FROM dbo.Parametros WHERE id=496) 
					     ELSE srv.cd_conceptofacturacion END AS 'cd_conceptofacturacion',
					CASE WHEN ISNULL(@bl_tomartiposervicionacionalidad,0)=1 AND ISNULL(@cd_tiposervicionacional,'')<>'' AND (CASE WHEN ISNULL(srv.in_nacionalidad,0)<>0 THEN srv.in_nacionalidad WHEN ISNULL(r.in_nacionalidad,0)=0 THEN 1 ELSE r.in_nacionalidad END)=1 THEN @cd_tiposervicionacional
						 WHEN ISNULL(@bl_tomartiposervicionacionalidad,0)=1 AND ISNULL(@cd_tiposerviciointernacional,'')<>'' AND (CASE WHEN ISNULL(srv.in_nacionalidad,0)<>0 THEN srv.in_nacionalidad WHEN ISNULL(r.in_nacionalidad,0)=0 THEN 1 ELSE r.in_nacionalidad END)=2 THEN @cd_tiposerviciointernacional
						 WHEN ISNULL(srv.cd_tiposervicio,'')='' THEN (SELECT RTRIM(Valor) FROM dbo.Parametros WHERE id=498)
						 ELSE srv.cd_tiposervicio END AS 'cd_tiposervicio',
					srv.cd_proveedores,
					p.RAZONCIAL AS ds_proveedores,

					NULL AS 'id_car',
					NULL AS dt_entrega,
					NULL AS in_cars,
					NULL AS cd_carcode,
					NULL AS "cd_conf_car",
					NULL AS cd_citysalida,
					NULL AS dt_retorno,
					NULL AS cd_cartype,
					NULL AS cd_currency,
					NULL AS "am_tarifacar",
					NULL AS cd_bookingsource,
					NULL AS cd_ratecode,
					
					htl.id AS 'id_htl',
					CASE WHEN htl.id Is Null Then getdate() Else htl.dt_checkin END AS dt_checkin, 
					CASE WHEN htl.id Is Null Then NULL Else in_guests END AS in_guests,
					CASE WHEN htl.id Is Null Then NULL Else cd_confirmation END AS cd_confirmation, 
					CASE WHEN htl.id Is Null Then NULL Else cd_city END AS cd_city, 
					CASE WHEN htl.id Is Null Then NULL Else cd_htlchain END AS cd_htlchain, 
					CASE WHEN htl.id Is Null Then getdate() Else htl.dt_checkout END AS dt_checkout,
					CASE WHEN htl.id Is Null Then NULL Else in_noches END AS in_noches, 
					CASE WHEN htl.id Is Null Then NULL Else replace(ds_htlname,char(9),'') END AS ds_htlname, 
					CASE WHEN htl.id Is Null Then NULL Else in_habs END AS in_habs, 
					CASE WHEN htl.id Is Null Then NULL Else cd_bed END AS cd_bed, 
					cd_ratecode AS cd_ratecode_htl, 
					NULL AS cd_htlcur,
					NULL AS am_htltarifa,
					NULL AS cd_agcur,
					NULL AS am_agtarifa,
					NULL AS ds_dir1,
					NULL AS ds_tel,
					NULL AS ds_fax,
					CASE WHEN ISNULL(v.cd_DepartCliente,'')<>'' THEN v.cd_DepartCliente ELSE r.cd_centrocosto END AS 'cd_centrocosto',
					0 as NumTktConj,
					'' 	 AS 'Respuesta',
					r.ds_solicita,
					srv.cd_paxidentificacion as 'cd_pax_CC',
					'' as 'ds_lapsoviaje',
					FPA.ds_archivo,
					r.ds_Observaciones,/*inicio rgelis 2014/03/28 req.15175*/
					ds_ClienteEmail = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_ClienteEmail,''))) = '' THEN ISNULL(c.email, '') ELSE r.ds_ClienteEmail END,
					r.cd_sucursal,
					r.cd_implante,
					bl_ClienteActualizar=0,
					bl_NotificacionMPD=0,
					cd_FormaPagoTAO='',
					cd_TarjetaCreditoTAO='',
					cd_NumeroTarjetaTAO='',
					cd_VencimientoTarjetaTAO='',
					cd_NumeroPolizaTAO='',
					cd_AnexoPolizaTAO='',
					am_PorDesFormaPagoTA=0, /*fin rgelis 2014/03/20 req.15175*/
					cd_Penalidad = '', /*rgelis 2014/07/16 req.20502*/
					ds_cc_vence = '', 
					ds_cc_vence2 = '', 
					ds_cc_autorizacion = '',
					ds_cc_autorizacion2 = '',
					ds_cc_voucher = '',
					ds_cc_voucher2 = '',
					ds_AutorizacionTarjetaTAO = '',
					ds_VoucherTarjetaTAO = '',
					am_fptao = 0,
					in_cc_cuotas = 0,
					in_cc_cuotas2 = 0,
					in_cuotasTarjetaTAO = 0,
					cd_TipoTarifaTAO = '',
					cd_TipoTiquete = '',
					ISNULL(r.am_TasaCambio,0) AS 'am_TasaCambio', /*rgelis 2014/11/08 req.22124*/ 
					r.cd_vendedor as cd_tiqueteador_facturador,
					r.bl_ahorro,
					in_CantidadTarifaTAO=0,
					in_CantidadSegmentoTAO=0,
					cd_tourcode='',
					r.ds_contrato,
					cd_PasaportePax='',
					ds_itinerarioaerolinea='',
					ds_tkt_prefixIata='',
					r.ds_Evento,
					isnull(r.cd_iata,'') AS 'cd_iata',
					ds_aero_codeIata='', 
					ReservaFactura = r.cd_codigo+'-C',
					r.cd_Ahorro,
					CASE WHEN ISNULL(v.cd_Categoria,'')<>'' THEN v.cd_Categoria ELSE @cd_categoria END AS 'cd_Categoria', 
					Id_FormasPagoAirPlus=NULL,
					cd_FormasPagoAirPlus='',
					ds_FormasPagoAirPlus='',
					cd_TarjetasCreditoAirPlus='',
					ds_numerotarjetaAirPlus='',
					am_PorFacParcial=100, 
					am_PorFacParcial_Utilizar=100,
					in_cantpax = 1,
					Id_Precompra = NULL,
					id_sucursal = NULL, --rgelis 2018/03/13 req.52081
					bl_cotizacion=0, --rgelis 2018/04/09 req.56942
					htl.cd_htl, --rgelis 2018/04/09 req.56942
					id_FormasPago = NULL,  --rgelis 2018/11/19 req.74409
					id_TarjetasCredito = NULL, --rgelis 2018/11/19 req.74409
					id_formapago_cliente=FPC.id,  --rgelis 2019/01/24 req.75925
					cd_formapago_cliente=FPC.cd_codigo, --rgelis 2019/01/24 req.75925
					ds_formapago_cliente=FPC.ds_nombre, --rgelis 2019/01/24 req.75925
					R.cd_fp_OtrosItems,
					srv.cd_auxiliar,
					r.cd_tipoventa

					,am_iva2=0
					,r.cd_licitacion
					,ds_descripcion=ISNULL(r.ds_descripcion,'')
					,id_tipoproveedor=ISNULL(TP.id,0)
					,cd_tipoproveedor=ISNULL(srv.cd_tipoproveedor,'')
					,ds_tipoproveedor=ISNULL(srv.ds_tipoproveedor,'')
					,cd_Consecutivo_variablesadicionales=NULL
					,cd_item = ''
				FROM dbo.ReservasGDS r
				INNER JOIN (
								SELECT DISTINCT top 100  rfa.cd_sucursal,rfa.cd_implante,rfa.id_reserva,rfa.ds_Archivo 
								from dbo.ReservasGDS_FacAuto rfa 
								inner join ReservaGDS_Servicios rd on rd.id_reserva = rfa.id_reserva
								inner join dbo.ReservasGDS r on r.id = rfa.id_reserva
								INNER JOIN @TValorInterfazGDSParametro PA ON PA.id_GDS = r.iden_gds AND PA.id_sys_entidades=131 AND PA.cd_codigo_maestro = 'FacAutoSrvGDS' AND PA.ds_valor = 'SI' --rgelis 2019/10/10 req.92991
								LEFT JOIN CLIENTES c ON (c.IDCLIENTE = R.cd_cliente OR c.IDCLIENTE= r.ds_cliid) /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
								LEFT JOIN dbo.ConfiguracionClientesFacAuto cc ON cc.cd_codigo = c.IDCLIENTE --rgelis 2018/04/13 req.58321
								where rd.bl_usada=0 and rd.bl_anulado = 0
								AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_sucursal, ',', 0, 1) s WHERE s.Codigo = rfa.cd_sucursal) OR ISNULL(@cd_sucursal,'')='' OR @FiltrarSucursalFactAuto = 0)
								AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_implante, ',', 0, 1) i WHERE i.Codigo = ISNULL(rfa.cd_implante,'0')) OR ISNULL(@cd_implante,'')='' OR @FiltrarImplanteFactAuto = 0)
								AND (cc.id IS NOT NULL OR @SoloUtilizarConfgClienteFacAuto=0)
							)fpa ON fpa.id_reserva = r.id
				INNER JOIN dbo.ReservaGDS_Servicios srv ON (r.id=srv.id_reserva)
				LEFT JOIN dbo.ReservaGDS_HTL htl ON (r.id=htl.id_reserva and (srv.id =htl.Id_ReservaGDS_Servicios OR srv.ds_indice=htl.ds_indice))
				LEFT JOIN dbo.ConceptoFacturacion cf ON cf.cd_codigo = srv.cd_conceptofacturacion
				LEFT JOIN dbo.TiposServicios ts ON ts.cd_codigo = srv.cd_tiposervicio
				LEFT JOIN dbo.PROVEEDORES p ON p.IDPROVE = srv.cd_proveedores
				LEFT JOIN CLIENTES c ON (c.IDCLIENTE = R.cd_cliente OR c.IDCLIENTE= r.ds_cliid) /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
				OUTER APPLY dbo.fnza_GetCategoriaVariableGDSTable(r.cd_codigo) AS v
				LEFT JOIN dbo.Sucursales ON Sucursales.cd_codigo = r.cd_sucursal
				LEFT JOIN dbo.Tiqueteadores ON Tiqueteadores.id = Sucursales.id_tiqueteador
				LEFT JOIN dbo.Implantes pcc_emite ON pcc_emite.cd_codigo = r.pcc_emite
				LEFT JOIN dbo.FormasPago FPC ON FPC.cd_codigo = r.cd_formapago_cliente--rgelis 2019/01/24 req.75925
				INNER JOIN @TValorInterfazGDSParametro PA ON PA.id_GDS = r.iden_gds AND PA.id_sys_entidades=131 AND PA.cd_codigo_maestro = 'FacAutoSrvGDS' AND PA.ds_valor = 'SI' --rgelis 2019/10/10 req.92991
				LEFT JOIN dbo.TipoProveedores TP ON TP.cd_codigo = srv.cd_tipoproveedor
				--WHERE fpa.cd_sucursal = @cd_sucursal 
				--AND (isnull(fpa.cd_implante,'0') = @cd_implante OR @cd_implante='0') /*rgelis 2014/03/28 req.15175*/
				--WHERE ISNULL(dbo.fnza_Get_ValorInterfazGDSParametro(r.iden_gds, 131, 'FacAutoSrvGDS', NULL),'')='SI' --rgelis 2019/09/25 req.92991			
				WHERE @bl_factura = 1 AND @GenerarCotizacion=0
				
			) AS consulta
			ORDER BY PNR
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
			
						
			RETURN @retval;
	    END TRY 
    																																			  
    	BEGIN CATCH 
    	-- Bloque CATCH (Manejo de excepciones)
 		
 			-- Tiempo de espera alcanzado --
		    IF ERROR_NUMBER() = 1222
		    BEGIN
      			SET @msg =  'No se pudo ejecutar el proceso. Tiempo de espera agotado.';
      			SET @retval = 1
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
	   	        
		       	SET @retry     = 1              ;
		       	SET @retrycont = @retrycont + 1 ; 

	    	 END
	    	 ELSE
		     BEGIN
		     	-- Error no manejado --
				IF (XACT_STATE() <> 0)
	   	        BEGIN 
														
					SET @retval = 1;
  	 				SET @msg =	'Ha ocurrido un error. InformaciÃ³n para soporte tecnico:'			+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							    'Numero: ' + isnull(CAST(ERROR_NUMBER()   AS VARCHAR(10)),'') 		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
								'Mensaje: ' + isnull(ERROR_MESSAGE(),'') 					   		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							 	'Severidad: ' + isnull(CAST(ERROR_SEVERITY() AS VARCHAR(10)),'') 	+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							 	'Estado: ' + isnull(CAST(ERROR_STATE()    AS VARCHAR(10)),'') 		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
								'Procedimiento: ' + 'spza_GDSFacturacionAutoJOB_Consultar'			+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
								'Linea: ' + isnull(CAST(ERROR_LINE() 	   AS VARCHAR(10)),''); 							
		
					RAISERROR (@msg,16,126);
					--Se debe auditar proceso fallido
					IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar	@id_proceso = @idproce   ,
											 			 			@id_usuario = @id_usuario ,
											 			 			@cd_status  = 0           , 
											 			 			@admsg      = @msg	  ;				
					RETURN @retval;
	   	        END 
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


GO

IF OBJECT_ID('dbo.spza_GenerarConceptosAutoJOB_Consultar', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spza_GenerarConceptosAutoJOB_Consultar;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE [dbo].[spza_GenerarConceptosAutoJOB_Consultar]
	-- Parametros del procedimiento
	@id_usuario			INT,
	@dt_fechaFactura	SMALLDATETIME	= NULL,
	@tasa_usd			MONEY			= 1	,
	@ZML_DatosXML		VARCHAR(MAX)	= NULL  
 
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
			@retval		TINYINT 		, -- Valor de retorno de este procedimiento: 0:Exito ; 1:Error(Bloque Catch)
			@Prefijo As Varchar(50)		, --Prefijo para indicar si es Dolares o Pesos
			@am_Contado MONEY			,
			@am_Credito MONEY			,
			@MonedaLocal Varchar(3)		,
			@TruncarDecimales Varchar(1),
			@IdMonedaLocal INT			,
			@bl_tomarFPAirplusTkt BIT	,
			@bl_tomarFPTaoTkt BIT;

	SELECT 	@retry				 = 1 		   ,
			@retrycont			 = 0		   ,
			@retval				 = 0;
  	
  	-- Manejo de tiempo de espera y de reintentos por bloqueo de tablas/registros  
   	SELECT @maxretries = convert(INT,Valor) FROM dbo.Parametros WHERE Id = 60 ;
	SELECT @timeout    = convert(NVARCHAR(4000),Valor) FROM dbo.Parametros WHERE Id = 50 ;		
	SET @stmt = N'SET LOCK_TIMEOUT '+ltrim(rtrim(@timeout))
	EXEC sp_executesql @stmt,N''
	
	Select @TruncarDecimales = Valor From parametros Where Id = 521

	WHILE ( (@retry = 1) AND (@retrycont <= @maxretries) )
	BEGIN
		SET @retry = 0;
    
    	-- Bloque TRY
    	BEGIN TRY 
    	    		
    		--Obteniendo informacion de seguridad y auditoria--
			/*EXEC dbo.spzaProcesoUsuario_Consultar @id_usuario   = @id_usuario       ,
												  @id_proceso   = @idproce 		    , 
												  @bl_permit    = @bl_permit OUTPUT , 
												  @bl_auditsuc  = @bl_as 	 OUTPUT , 
												  @bl_auditfail = @bl_af 	 OUTPUT ;
			IF (@bl_permit = 0)
			BEGIN 
				SELECT 'No posee permisos suficientes para ejecutar esta acciÃ³n.' AS 'Respuesta'
				RETURN @retval;
			END */

			
			
			--Instrucciones del procedimiento-----------------------------------------
			DECLARE @NumeroDecimales INT
			SELECT  @NumeroDecimales = Valor from parametros where Id = 33

			Select @MonedaLocal = Valor From parametros where id=10
			Select @IdMonedaLocal =  Id From Monedas_iata Where cd_codigo=@MonedaLocal

			DECLARE @PaisLocal VARCHAR(50)
			SELECT @PaisLocal = Valor From parametros where id=240

			DECLARE @bl_utilizarcencostosuc BIT,@bl_utilizarcencostoimp BIT
			SELECT @bl_utilizarcencostosuc = CASE WHEN RTRIM(LTRIM(Valor))='S' THEN 1 ELSE 0 END From parametros where id=134
			SELECT @bl_utilizarcencostoimp = CASE WHEN RTRIM(LTRIM(Valor))='S' THEN 1 ELSE 0 END From parametros where id=137
			SET @bl_utilizarcencostosuc = ISNULL(@bl_utilizarcencostosuc,0)
			SET @bl_utilizarcencostoimp = ISNULL(@bl_utilizarcencostoimp,0)

			SELECT @bl_tomarFPAirplusTkt = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=608
			SELECT @bl_tomarFPTaoTkt = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=609
			SET @bl_tomarFPAirplusTkt=ISNULL(@bl_tomarFPAirplusTkt,0)
			SET @bl_tomarFPTaoTkt=isnull(@bl_tomarFPTaoTkt,0)

			IF OBJECT_ID('tempdb..#Concepto') IS NOT NULL DROP TABLE #Concepto;
			CREATE TABLE #Concepto 
			(Id INT IDENTITY
			,cd_cliente VARCHAR(25) COLLATE DATABASE_DEFAULT
			,id_conceptofacturacion INT
            ,id_tiposservicios INT
            ,in_nacionalidad INT
			,id_aerolinea	INT
			,id_moneda	INT
            ,ds_paxname VARCHAR(30) COLLATE DATABASE_DEFAULT
            ,ds_paxape VARCHAR(30) COLLATE DATABASE_DEFAULT
            ,cd_paxtype CHAR(3) COLLATE DATABASE_DEFAULT
            ,ds_paxClasificacion CHAR(6) COLLATE DATABASE_DEFAULT
			,cd_tiquete CHAR(11) COLLATE DATABASE_DEFAULT
			,cd_proveedores VARCHAR(25) COLLATE DATABASE_DEFAULT
			,dt_llegada SMALLDATETIME
			,dt_salida SMALLDATETIME
			,cd_cencosto VARCHAR(16) COLLATE DATABASE_DEFAULT
			,cd_auxiliar VARCHAR(16) COLLATE DATABASE_DEFAULT
			,cd_item VARCHAR(16) COLLATE DATABASE_DEFAULT
			,CodigoReserva VARCHAR(25) COLLATE DATABASE_DEFAULT
			,am_tarifa MONEY
			,am_total MONEY
			,ColId VARCHAR(25) COLLATE DATABASE_DEFAULT
			,cd_Consecutivo_depende VARCHAR(50) COLLATE DATABASE_DEFAULT
			,am_ValorComision MONEY
			,am_ImpuestoComision MONEY
			,am_totalfactura MONEY
			,cd_tourcode VARCHAR(25) COLLATE DATABASE_DEFAULT
			,am_Contado MONEY --rgelis 2017/02/11 req.47323
			,am_Credito MONEY --rgelis 2017/02/11 req.47323
			,cd_tktrevisado VARCHAR(14) COLLATE DATABASE_DEFAULT --inicio rgelis 2017/09/19 req.5282
			,id_TiposDocumento INT
            ,cd_Penalidad VARCHAR(14) COLLATE DATABASE_DEFAULT
			,cd_TipoTiqueteGDS VARCHAR(3) COLLATE DATABASE_DEFAULT --fin rgelis 2017/09/19 req.5282
			,am_TasaCambio MONEY --rgelis 2017/10/25 req.54014
			,ds_itinerario VARCHAR(123) COLLATE DATABASE_DEFAULT --rgelis 2018/04/16 req.57446
			,id_sucursal INT --inicio rgelis 2018/05/07 req.58559
			,id_implante INT
			,id_FormasPago INT 
			,cd_TarjetasCredito VARCHAR(4) COLLATE DATABASE_DEFAULT --fin rgelis 2018/05/07 req.58559
			,iden_gds INT
			,cd_codigotc VARCHAR(2) COLLATE DATABASE_DEFAULT
			,ds_numerotc VARCHAR(25) COLLATE DATABASE_DEFAULT
			,ds_vencetc VARCHAR(5) COLLATE DATABASE_DEFAULT
			,ds_autorizaciontc VARCHAR(25) COLLATE DATABASE_DEFAULT
			,ds_vouchertc VARCHAR(25) COLLATE DATABASE_DEFAULT
			,in_cuotastc INT
			,id_FormasPagoTAO INT 
			,cd_codigotcTAO VARCHAR(2) COLLATE DATABASE_DEFAULT
			,ds_numerotcTAO VARCHAR(25) COLLATE DATABASE_DEFAULT
			,ds_vencetcTAO VARCHAR(5) COLLATE DATABASE_DEFAULT
			,ds_autorizaciontcTAO VARCHAR(25) COLLATE DATABASE_DEFAULT
			,ds_vouchertcTAO VARCHAR(25) COLLATE DATABASE_DEFAULT
			,in_cuotastcTAO INT 
			)
			
			DECLARE @ExecSQL VARCHAR(MAX) = 'INSERT INTO #Concepto ' + @ZML_DatosXML;
			EXEC(@ExecSQL);
			--select * from #Concepto
			--RETURN 1
			
			-- Loop variables
			DECLARE @cur_cd_cliente VARCHAR(25),
					@cur_id_conceptofacturacion INT,
					@cur_in_nacionalidad INT,
					@cur_id_aerolinea INT,
					@cur_id_moneda INT,
					@cur_ds_paxname VARCHAR(30),
					@cur_ds_paxape VARCHAR(30),
					@cur_cd_paxtype CHAR(3),
					@cur_ds_paxClasificacion CHAR(6),
					@cur_cd_tiquete CHAR(11),
					@cur_dt_llegada SMALLDATETIME,
					@cur_dt_salida SMALLDATETIME,
					@cur_cd_cencosto VARCHAR(16),
					@cur_cd_auxiliar VARCHAR(16),
					@cur_cd_item VARCHAR(16),
					@cur_CodigoReserva VARCHAR(25),
					@cur_id_sucursal INT,
					@cur_id_implante INT,
					@cur_id_FormasPago INT,
					@cur_cd_TarjetasCredito VARCHAR(4),
					@cur_id_TarjetasCredito INT,
					@cur_iden_gds INT,
					@cur_ColId VARCHAR(25),
					@cur_cd_Consecutivo_depende VARCHAR(50),
					@cur_cd_codigotc VARCHAR(2), 
					@cur_ds_numerotc VARCHAR(25),
					@cur_ds_vencetc VARCHAR(5),
					@cur_ds_autorizaciontc VARCHAR(25), 
					@cur_ds_vouchertc VARCHAR(25), 
					@cur_in_cuotastc INT,
					@cur_id_FormasPagoTAO INT,
					@cur_id_TarjetasCreditoTAO INT,
					@cur_cd_codigotcTAO VARCHAR(2),
					@cur_ds_numerotcTAO VARCHAR(25),
					@cur_ds_vencetcTAO VARCHAR(5),
					@cur_ds_autorizaciontcTAO VARCHAR(25),
					@cur_ds_vouchertcTAO VARCHAR(25),
					@cur_in_cuotastcTAO INT

			DECLARE @cur_id_reserva_int INT;

			DECLARE @OriginalConcepto TABLE 
			(
			 cd_cliente VARCHAR(25)
			,id_conceptofacturacion INT
            ,in_nacionalidad INT
			,id_aerolinea	INT
			,id_moneda	INT
            ,ds_paxname VARCHAR(30)
            ,ds_paxape VARCHAR(30)
            ,cd_paxtype CHAR(3)
            ,ds_paxClasificacion CHAR(6)
			,cd_tiquete CHAR(11)
			,dt_llegada SMALLDATETIME
			,dt_salida SMALLDATETIME
			,cd_cencosto VARCHAR(16)
			,cd_auxiliar VARCHAR(16)
			,cd_item VARCHAR(16)
			,CodigoReserva VARCHAR(25)
			,id_sucursal INT
			,id_implante INT
			,id_FormasPago INT 
			,cd_TarjetasCredito VARCHAR(4)
			,iden_gds INT
			,ColId VARCHAR(25)
			,cd_Consecutivo_depende VARCHAR(50)
			,cd_codigotc VARCHAR(2) 
			,ds_numerotc VARCHAR(25)
			,ds_vencetc VARCHAR(5)
			,ds_autorizaciontc VARCHAR(25) 
			,ds_vouchertc VARCHAR(25) 
			,in_cuotastc INT
			,id_FormasPagoTAO INT
			,cd_codigotcTAO VARCHAR(2)
			,ds_numerotcTAO VARCHAR(25)
			,ds_vencetcTAO VARCHAR(5)
			,ds_autorizaciontcTAO VARCHAR(25)
			,ds_vouchertcTAO VARCHAR(25)
			,in_cuotastcTAO INT
			)

			INSERT INTO @OriginalConcepto (cd_cliente, id_conceptofacturacion, in_nacionalidad, id_aerolinea, id_moneda, ds_paxname, ds_paxape, cd_paxtype, ds_paxClasificacion, cd_tiquete, dt_llegada, dt_salida, cd_cencosto, cd_auxiliar, cd_item, CodigoReserva, id_sucursal, id_implante, id_FormasPago, cd_TarjetasCredito, iden_gds, ColId, cd_Consecutivo_depende, cd_codigotc, ds_numerotc, ds_vencetc, ds_autorizaciontc, ds_vouchertc, in_cuotastc, id_FormasPagoTAO, cd_codigotcTAO, ds_numerotcTAO, ds_vencetcTAO, ds_autorizaciontcTAO, ds_vouchertcTAO, in_cuotastcTAO)
			SELECT cd_cliente, id_conceptofacturacion, in_nacionalidad, id_aerolinea, id_moneda, ds_paxname, ds_paxape, cd_paxtype, ds_paxClasificacion, cd_tiquete, dt_llegada, dt_salida, cd_cencosto, cd_auxiliar, cd_item, CodigoReserva, id_sucursal, id_implante, id_FormasPago, cd_TarjetasCredito, iden_gds, ColId, cd_Consecutivo_depende, cd_codigotc, ds_numerotc, ds_vencetc, ds_autorizaciontc, ds_vouchertc, in_cuotastc, id_FormasPagoTAO, cd_codigotcTAO, ds_numerotcTAO, ds_vencetcTAO, ds_autorizaciontcTAO, ds_vouchertcTAO, in_cuotastcTAO 
			FROM #Concepto
			
			--select * from @OriginalConcepto
			--return 1
			-- 1. Construir @ListaReservas
			DECLARE @ListaReservas VARCHAR(MAX) = '';
			SELECT @ListaReservas = @ListaReservas + CAST(id_reserva AS VARCHAR) + ',' 
			FROM (
				SELECT DISTINCT r.id AS id_reserva 
				FROM dbo.ReservasGDS r 
				INNER JOIN #Concepto c ON r.cd_codigo = c.CodigoReserva
			) X;
			IF LEN(@ListaReservas) > 0 SET @ListaReservas = LEFT(@ListaReservas, LEN(@ListaReservas) - 1);

			-- 2. Cargar Itinerarios y FEEs Masivamente
			IF OBJECT_ID('tempdb..#ItinerariosJob') IS NOT NULL DROP TABLE #ItinerariosJob;
			CREATE TABLE #ItinerariosJob (id INT, id_reserva INT, orden INT, cd_origen VARCHAR(10), cd_destino VARCHAR(10), cd_clase VARCHAR(10), fecha_salida VARCHAR(20), hora_salida VARCHAR(10), hora_llegada VARCHAR(10), terminal VARCHAR(50), cd_aero_siglas VARCHAR(10), cd_farebasis VARCHAR(50), ds_NumVuelo VARCHAR(50), ds_TipoVuelo VARCHAR(50), am_valor MONEY, bl_NoUtilizado BIT, am_co2 MONEY);
			
			IF OBJECT_ID('tempdb..#FeesJob') IS NOT NULL DROP TABLE #FeesJob;
			CREATE TABLE #FeesJob (id_reserva INT, cd_tiquete VARCHAR(50), in_orden INT, cd_conceptofac VARCHAR(50), cd_subcodigo VARCHAR(50), am_valor MONEY, ds_servicio VARCHAR(200));
																																
			IF ISNULL(@ListaReservas,'') <> ''
			BEGIN 
				INSERT INTO #ItinerariosJob EXEC dbo.spza_ReservasGDSJOB_Itinerario @id_reserva = @ListaReservas;
				INSERT INTO #FeesJob EXEC dbo.spza_ReservasGDS_FEEJOB_Consultar @Id_Reservas = @ListaReservas;
			END
			
			DECLARE cur_conceptos CURSOR LOCAL FAST_FORWARD FOR
			SELECT cd_cliente, id_conceptofacturacion, in_nacionalidad, id_aerolinea, id_moneda, ds_paxname, ds_paxape, cd_paxtype, ds_paxClasificacion, cd_tiquete, dt_llegada, dt_salida, cd_cencosto, cd_auxiliar, cd_item, CodigoReserva, id_sucursal, id_implante, id_FormasPago, cd_TarjetasCredito, iden_gds, ColId, cd_Consecutivo_depende, cd_codigotc, ds_numerotc, ds_vencetc, ds_autorizaciontc, ds_vouchertc, in_cuotastc, id_FormasPagoTAO, cd_codigotcTAO, ds_numerotcTAO, ds_vencetcTAO, ds_autorizaciontcTAO, ds_vouchertcTAO, in_cuotastcTAO 
			FROM @OriginalConcepto

			OPEN cur_conceptos
			FETCH NEXT FROM cur_conceptos INTO @cur_cd_cliente, @cur_id_conceptofacturacion, @cur_in_nacionalidad, @cur_id_aerolinea, @cur_id_moneda, @cur_ds_paxname, @cur_ds_paxape, @cur_cd_paxtype, @cur_ds_paxClasificacion, @cur_cd_tiquete, @cur_dt_llegada, @cur_dt_salida, @cur_cd_cencosto, @cur_cd_auxiliar, @cur_cd_item, @cur_CodigoReserva, @cur_id_sucursal, @cur_id_implante, @cur_id_FormasPago, @cur_cd_TarjetasCredito, @cur_iden_gds, @cur_ColId, @cur_cd_Consecutivo_depende, @cur_cd_codigotc, @cur_ds_numerotc, @cur_ds_vencetc, @cur_ds_autorizaciontc, @cur_ds_vouchertc, @cur_in_cuotastc, @cur_id_FormasPagoTAO, @cur_cd_codigotcTAO, @cur_ds_numerotcTAO, @cur_ds_vencetcTAO, @cur_ds_autorizaciontcTAO, @cur_ds_vouchertcTAO, @cur_in_cuotastcTAO

			WHILE @@FETCH_STATUS = 0
			BEGIN
				SELECT @cur_id_reserva_int = id FROM dbo.ReservasGDS WHERE cd_codigo = @cur_CodigoReserva

				IF @cur_id_reserva_int IS NOT NULL
				BEGIN
					-- 1. Consultar itinerario y actualizar en @Concepto
					DECLARE @ItinTable TABLE (
						id INT, id_reserva INT, orden INT, cd_origen VARCHAR(10), cd_destino VARCHAR(10),
						cd_clase VARCHAR(10), fecha_salida VARCHAR(20), hora_salida VARCHAR(10),
						hora_llegada VARCHAR(10), terminal VARCHAR(50), cd_aero_siglas VARCHAR(10),
						cd_farebasis VARCHAR(50), ds_NumVuelo VARCHAR(50), ds_TipoVuelo VARCHAR(50),
						am_valor MONEY, bl_NoUtilizado BIT, am_co2 MONEY
					)
					DELETE FROM @ItinTable

					INSERT INTO @ItinTable
					SELECT id, id_reserva, orden, cd_origen, cd_destino, cd_clase, fecha_salida, hora_salida, hora_llegada, terminal, cd_aero_siglas, cd_farebasis, ds_NumVuelo, ds_TipoVuelo, am_valor, bl_NoUtilizado, am_co2
					FROM #ItinerariosJob WHERE id_reserva = @cur_id_reserva_int;

					DECLARE @ds_itinerario VARCHAR(123) = ''
					SELECT @ds_itinerario = CASE WHEN @ds_itinerario = '' THEN cd_origen + '-' + cd_destino ELSE @ds_itinerario + '-' + cd_destino END
					FROM @ItinTable
					ORDER BY orden

					IF @ds_itinerario <> ''
					BEGIN
						UPDATE #Concepto
						SET ds_itinerario = @ds_itinerario
						WHERE cd_tiquete = @cur_cd_tiquete AND CodigoReserva = @cur_CodigoReserva
					END

					-- 2. Consultar FEEs/cargos adicionales por tiquete (solo si es tiquete, id_conceptofacturacion 1 o 2)
					IF @cur_id_conceptofacturacion IN (1, 2)
					BEGIN
						DECLARE @FeeTable TABLE (
							id_reserva INT,
							cd_tiquete VARCHAR(50) COLLATE DATABASE_DEFAULT,
							in_orden INT,
							cd_conceptofac VARCHAR(50) COLLATE DATABASE_DEFAULT,
							cd_subcodigo VARCHAR(50) COLLATE DATABASE_DEFAULT,
							am_valor MONEY,
							ds_servicio VARCHAR(200) COLLATE DATABASE_DEFAULT
						)
						DELETE FROM @FeeTable

						INSERT INTO @FeeTable(id_reserva,cd_tiquete,in_orden,cd_conceptofac,cd_subcodigo,am_valor,ds_servicio)
						SELECT F.id_reserva, F.cd_tiquete, F.in_orden, F.cd_conceptofac, F.cd_subcodigo, F.am_valor, ds_servicio = CASE WHEN ISNULL(F.ds_servicio,'')='' THEN CF.ds_nombre+' '+F.cd_tiquete ELSE F.ds_servicio END COLLATE DATABASE_DEFAULT
						FROM #FeesJob F 
						LEFT JOIN dbo.ConceptoFacturacion CF ON CF.cd_codigo COLLATE DATABASE_DEFAULT = F.cd_conceptofac COLLATE DATABASE_DEFAULT
						WHERE F.id_reserva = @cur_id_reserva_int 
						AND (F.cd_tiquete = @cur_cd_tiquete OR F.cd_tiquete = CASE WHEN LEN(@cur_cd_tiquete)>=13 THEN RIGHT(@cur_cd_tiquete,LEN(@cur_cd_tiquete)-3) ELSE @cur_cd_tiquete END);

						SELECT @cur_id_TarjetasCredito = id FROM dbo.TarjetasCredito WHERE cd_codigo=@cur_cd_TarjetasCredito
						SELECT @cur_id_TarjetasCreditoTAO = id FROM dbo.TarjetasCredito WHERE cd_codigo=@cur_cd_codigotcTAO

						INSERT INTO #GenerarConceptosAuto (
							id_ConceptoFacturacion,
							cd_ConceptoFacturacion,
							ds_ConceptoFacturacion,
							id_TiposConceptFac,
							bl_contorlarCargImp,
							bl_CalculoAutoValoresFacturacion,
							id_TiposServicio,
							cd_TiposServicio,
							ds_TiposServicio,
							cd_proveedores,
							ds_proveedores,
							cd_tiquete,
							ds_servicio,
							ds_descrip,
							ds_paxname,
							ds_paxape,
							cd_paxtype,
							ds_paxClasificacion,
							in_nacionalidad,
							dt_llegada,
							dt_salida,
							cd_cencosto,
							cd_auxiliar,
							cd_item,
							Valor,
							am_Contado,
							am_Credito,
							ColId,
							cd_Consecutivo_depende,
							CodigoReserva,
							am_ImpuestoComision,
							Respuesta,
							bl_RutaExentaIva,
							id_FormasPago,
							id_TarjetasCredito,
							am_basedescuento,
							am_pordescuento,
							id_FormasPagoAirPlus,
							cd_FormasPagoAirPlus,
							ds_FormasPagoAirPlus,
							id_TarjetasCreditoAirPlus,
							cd_TarjetasCreditoAirPlus,
							ds_numerotarjetaAirPlus,
							cd_codigotc, 
							ds_numerotc,
							ds_vencetc, 
							ds_autorizaciontc,
							ds_vouchertc, 
							in_cuotastc 
						)
						SELECT 
							id_ConceptoFacturacion=C.id,
							cd_ConceptoFacturacion=C.cd_codigo,
							ds_ConceptoFacturacion=C.ds_nombre,
							id_TiposConceptFac=C.id_TiposConceptoFacturacion,
							bl_contorlarCargImp=C.bl_contorlarCargImp,
							bl_CalculoAutoValoresFacturacion=C.bl_CalculoAutoValoresFacturacion,
							id_TiposServicio=TS.id,
							cd_TiposServicio=TS.cd_codigo,
							ds_TiposServicio=TS.ds_nombre,
							cd_proveedores='',
							ds_proveedores='',
							cd_tiquete=F.cd_tiquete,
							ds_servicio=F.ds_servicio,
							ds_descrip=F.ds_servicio,
							ds_paxname=@cur_ds_paxname,
							ds_paxape=@cur_ds_paxape,
							cd_paxtype=@cur_cd_paxtype,
							ds_paxClasificacion=@cur_ds_paxClasificacion,
							in_nacionalidad=@cur_in_nacionalidad,
							dt_llegada=@cur_dt_llegada,
							dt_salida=@cur_dt_salida,
							cd_cencosto=@cur_cd_cencosto,
							cd_auxiliar=@cur_cd_auxiliar,
							cd_item=@cur_cd_item,
							Valor=F.am_valor,
							am_Contado=CASE WHEN ISNULL(@cur_id_FormasPago,0)<>2 THEN F.am_valor ELSE 0 END,
							am_Credito=CASE WHEN ISNULL(@cur_id_FormasPago,0)=2 THEN F.am_valor ELSE 0 END,
							ColId=@cur_ColId,
							cd_Consecutivo_depende=@cur_cd_Consecutivo_depende,
							CodigoReserva=@cur_CodigoReserva,
							am_ImpuestoComision=0,
							Respuesta='',
							bl_RutaExentaIva=0,
							id_FormasPago=@cur_id_FormasPago,
							id_TarjetasCredito=@cur_id_TarjetasCredito,
							am_basedescuento=0,
							am_pordescuento=0,
							id_FormasPagoAirPlus=NULL,
							cd_FormasPagoAirPlus='',
							ds_FormasPagoAirPlus='',
							id_TarjetasCreditoAirPlus=NULL,
							cd_TarjetasCreditoAirPlus='',
							ds_numerotarjetaAirPlus='',
							cd_codigotc=@cur_cd_codigotc, 
							ds_numerotc=@cur_ds_numerotc,
							ds_vencetc=@cur_ds_vencetc, 
							ds_autorizaciontc=@cur_ds_autorizaciontc,
							ds_vouchertc=@cur_ds_vouchertc, 
							in_cuotastc=@cur_in_cuotastc
						FROM @FeeTable F
						INNER JOIN dbo.ConceptoFacturacion C ON C.cd_codigo = F.cd_conceptofac
						LEFT JOIN dbo.tiposServicio_asignados TSA ON (TSA.id_ConceptoFacturacion = C.id AND TSA.bl_Valdeft = 1) 
						LEFT JOIN dbo.TiposServicios TS ON TS.id = TSA.id_TipoServicio

						-- Auto-TAO Configuration
						DECLARE @AUTOTAO CHAR(1) = (SELECT LTRIM(RTRIM(Valor)) FROM dbo.Parametros WHERE id = 192);
						DECLARE @AUTOTAOAMADEUS CHAR(1) = (SELECT LTRIM(RTRIM(Valor)) FROM dbo.Parametros WHERE id = 213);
						
						DECLARE @ValorTAO MONEY = 0;
						
						-- Validar si el cliente tiene config especial
						DECLARE @bl_TAO BIT, @am_TarifaOneWay MONEY, @am_TarifaRoundTrip MONEY, @am_Tarifa_USD300 MONEY, @am_Tarifa_USD300_USD500 MONEY, @am_Tarifa_USD500_USD800 MONEY, @am_Tarifa_USD800 MONEY;
						SELECT TOP 1 @bl_TAO = ISNULL(bl_TAO,0), @am_TarifaOneWay = am_TarifaOneWay, @am_TarifaRoundTrip = am_TarifaRoundTrip, @am_Tarifa_USD300 = am_Tarifa_USD300, @am_Tarifa_USD300_USD500 = am_Tarifa_USD300_USD500, @am_Tarifa_USD500_USD800 = am_Tarifa_USD500_USD800, @am_Tarifa_USD800 = am_Tarifa_USD800
						FROM dbo.Configuracion_remisiones WHERE id_cliente = @cur_cd_cliente;

						IF @bl_TAO = 1 OR @AUTOTAO = 'S' OR (@AUTOTAOAMADEUS = 'S' AND @cur_iden_gds = 2)
						BEGIN
							IF ISNULL(@bl_TAO, 0) = 0
							BEGIN
								-- Cargar de parametros generales
								SELECT @am_TarifaOneWay = CAST(Valor AS MONEY) FROM dbo.Parametros WHERE id = 61;
								SELECT @am_TarifaRoundTrip = CAST(Valor AS MONEY) FROM dbo.Parametros WHERE id = 62;
								SELECT @am_Tarifa_USD300 = CAST(Valor AS MONEY) FROM dbo.Parametros WHERE id = 67;
								SELECT @am_Tarifa_USD300_USD500 = CAST(Valor AS MONEY) FROM dbo.Parametros WHERE id = 68;
								SELECT @am_Tarifa_USD500_USD800 = CAST(Valor AS MONEY) FROM dbo.Parametros WHERE id = 69;
								SELECT @am_Tarifa_USD800 = CAST(Valor AS MONEY) FROM dbo.Parametros WHERE id = 70;
							END

							-- Determinar rango basado en nacionalidad e itinerario
							DECLARE @tarifa_base MONEY;
							SELECT @tarifa_base = am_tarifa FROM #Concepto WHERE cd_tiquete = @cur_cd_tiquete AND CodigoReserva = @cur_CodigoReserva;

							IF @cur_in_nacionalidad = 1
							BEGIN
								IF dbo.fnza_ItinerarioTipo(@ds_itinerario) = 'OW' SET @ValorTAO = @am_TarifaOneWay;
								ELSE SET @ValorTAO = @am_TarifaRoundTrip;
							END
							ELSE
							BEGIN
								-- Convertir a USD si aplica, aquÃ­ usamos la tarifa base por simplicidad
								DECLARE @TarifaUSD MONEY = ISNULL(@tarifa_base, 0); 
								IF @TarifaUSD <= 300 SET @ValorTAO = @am_Tarifa_USD300;
								ELSE IF @TarifaUSD <= 500 SET @ValorTAO = @am_Tarifa_USD300_USD500;
								ELSE IF @TarifaUSD <= 800 SET @ValorTAO = @am_Tarifa_USD500_USD800;
								ELSE SET @ValorTAO = @am_Tarifa_USD800;
							END

							IF ISNULL(@ValorTAO, 0) > 0
							BEGIN
								INSERT INTO #GenerarConceptosAuto (
										id_ConceptoFacturacion,
										cd_ConceptoFacturacion,
										ds_ConceptoFacturacion,
										id_TiposConceptFac,
										bl_contorlarCargImp,
										bl_CalculoAutoValoresFacturacion,
										id_TiposServicio,
										cd_TiposServicio,
										ds_TiposServicio,
										cd_proveedores,
										ds_proveedores,
										cd_tiquete,
										ds_servicio,
										ds_descrip,
										ds_paxname,
										ds_paxape,
										cd_paxtype,
										ds_paxClasificacion,
										in_nacionalidad,
										dt_llegada,
										dt_salida,
										cd_cencosto,
										cd_auxiliar,
										cd_item,
										Valor,
										am_Contado,
										am_Credito,
										ColId,
										cd_Consecutivo_depende,
										CodigoReserva,
										am_ImpuestoComision,
										Respuesta,
										bl_RutaExentaIva,
										id_FormasPago,
										id_TarjetasCredito,
										am_basedescuento,
										am_pordescuento,
										id_FormasPagoAirPlus,
										cd_FormasPagoAirPlus,
										ds_FormasPagoAirPlus,
										id_TarjetasCreditoAirPlus,
										cd_TarjetasCreditoAirPlus,
										ds_numerotarjetaAirPlus,
										cd_codigotc, 
										ds_numerotc,
										ds_vencetc, 
										ds_autorizaciontc,
										ds_vouchertc, 
										in_cuotastc
								)
								SELECT
										id_ConceptoFacturacion=@cur_in_nacionalidad+3,
										cd_ConceptoFacturacion=CASE WHEN @cur_in_nacionalidad=2 THEN 'CAI' ELSE 'CAN' END,
										ds_ConceptoFacturacion='Tarifa Adminstrativa '+CASE WHEN @cur_in_nacionalidad=2 THEN 'Internacional' ELSE 'Nacional' END,
										id_TiposConceptFac=3,
										bl_contorlarCargImp=0,
										bl_CalculoAutoValoresFacturacion=0,
										id_TiposServicio=NULL,
										cd_TiposServicio='',
										ds_TiposServicio='',
										cd_proveedores='',
										ds_proveedores='',
										cd_tiquete=@cur_cd_tiquete,
										ds_servicio='Tarifa Adminstrativa '+CASE WHEN @cur_in_nacionalidad=2 THEN 'Internacional' ELSE 'Nacional' END + ' Tiquete: ' + ISNULL(@cur_cd_tiquete,''),
										ds_descrip='Tarifa Adminstrativa '+CASE WHEN @cur_in_nacionalidad=2 THEN 'Internacional' ELSE 'Nacional' END + ' Tiquete: ' + ISNULL(@cur_cd_tiquete,''),
										ds_paxname=@cur_ds_paxname,
										ds_paxape=@cur_ds_paxape,
										cd_paxtype=@cur_cd_paxtype,
										ds_paxClasificacion=@cur_ds_paxClasificacion,
										in_nacionalidad=@cur_in_nacionalidad,
										dt_llegada=@cur_dt_llegada,
										dt_salida=@cur_dt_salida,
										cd_cencosto=@cur_cd_cencosto,
										cd_auxiliar=@cur_cd_auxiliar,
										cd_item=@cur_cd_item,
										Valor=@ValorTAO,
										am_Contado=CASE WHEN (CASE WHEN ISNULL(@cur_id_FormasPagoTAO,0)<>0 THEN ISNULL(@cur_id_FormasPagoTAO,0) ELSE ISNULL(@cur_id_FormasPago,0) END)<>2 THEN @ValorTAO ELSE 0 END,
										am_Credito=CASE WHEN (CASE WHEN ISNULL(@cur_id_FormasPagoTAO,0)<>0 THEN ISNULL(@cur_id_FormasPagoTAO,0) ELSE ISNULL(@cur_id_FormasPago,0) END)=2 THEN @ValorTAO ELSE 0 END,
										ColId=@cur_ColId,
										cd_Consecutivo_depende=@cur_cd_Consecutivo_depende,
										CodigoReserva=@cur_CodigoReserva,
										am_ImpuestoComision=0,
										Respuesta='',
										bl_RutaExentaIva=0,
										id_FormasPago=CASE WHEN ISNULL(@cur_id_FormasPagoTAO,0)<>0 THEN @cur_id_FormasPagoTAO ELSE @cur_id_FormasPago END,
										id_TarjetasCredito=CASE WHEN ISNULL(@cur_id_TarjetasCreditoTAO,0)<>0 THEN @cur_id_TarjetasCreditoTAO ELSE @cur_id_TarjetasCredito END,
										am_basedescuento=0,
										am_pordescuento=0,
										id_FormasPagoAirPlus=NULL,
										cd_FormasPagoAirPlus='',
										ds_FormasPagoAirPlus='',
										id_TarjetasCreditoAirPlus=NULL,
										cd_TarjetasCreditoAirPlus='',
										ds_numerotarjetaAirPlus='',
										cd_codigotc=CASE WHEN ISNULL(@cur_cd_codigotcTAO,'')<>'' THEN @cur_cd_codigotcTAO ELSE @cur_cd_codigotc END, 
										ds_numerotc=CASE WHEN ISNULL(@cur_ds_numerotcTAO,'')<>'' THEN @cur_ds_numerotcTAO ELSE @cur_ds_numerotc END,
										ds_vencetc=CASE WHEN ISNULL(@cur_ds_vencetcTAO,'')<>'' THEN @cur_ds_vencetcTAO ELSE @cur_ds_vencetc END, 
										ds_autorizaciontc=CASE WHEN ISNULL(@cur_ds_autorizaciontcTAO,'')<>'' THEN @cur_ds_autorizaciontcTAO ELSE @cur_ds_autorizaciontc END,
										ds_vouchertc=CASE WHEN ISNULL(@cur_ds_vouchertcTAO,'')<>'' THEN @cur_ds_vouchertcTAO ELSE @cur_ds_vouchertc END, 
										in_cuotastc=CASE WHEN ISNULL(@cur_in_cuotastcTAO,0)<>0 THEN @cur_in_cuotastcTAO ELSE @cur_in_cuotastc END
							END
						END
					END
					
					-- 3. Consultar servicios adicionales de la tabla ReservaGDS_Servicios
					/*
					INSERT INTO #Concepto (
						cd_cliente, id_conceptofacturacion, id_tiposservicios, in_nacionalidad,
						id_aerolinea, id_moneda, ds_paxname, ds_paxape, cd_paxtype, ds_paxClasificacion,
						cd_tiquete, cd_proveedores, dt_llegada, dt_salida, cd_cencosto, cd_auxiliar, cd_item,
						CodigoReserva, am_tarifa, am_total, ColId, cd_Consecutivo_depende,
						am_ValorComision, am_ImpuestoComision, am_totalfactura, cd_tourcode,
						am_Contado, am_Credito, cd_tktrevisado, id_TiposDocumento, cd_Penalidad,
						cd_TipoTiqueteGDS, am_TasaCambio, ds_itinerario, id_sucursal, id_implante,
						id_FormasPago, cd_TarjetasCredito, iden_gds
					)
					SELECT 
						@cur_cd_cliente,
						CASE WHEN cd_conceptofacturacion = 'CAN' THEN 4
							 WHEN cd_conceptofacturacion = 'CAI' THEN 5
							 ELSE 3 END,
						NULL,
						ISNULL(in_nacionalidad, @cur_in_nacionalidad),
						@cur_id_aerolinea,
						@cur_id_moneda,
						ISNULL(ds_pax_firstnm, @cur_ds_paxname),
						ISNULL(ds_pax_lastnm, @cur_ds_paxape),
						ISNULL(ds_pax_prefix, @cur_cd_paxtype),
						@cur_ds_paxClasificacion,
						@cur_cd_tiquete,
						cd_proveedores,
						ISNULL(dt_checkout, @cur_dt_llegada),
						ISNULL(dt_checkin, @cur_dt_salida),
						@cur_cd_cencosto,
						ISNULL(cd_auxiliar, @cur_cd_auxiliar),
						@cur_cd_item,
						@cur_CodigoReserva,
						am_tarifa,
						am_tarifa + ISNULL(am_iva, 0),
						CAST(id AS VARCHAR(25)),
						@cur_cd_tiquete,
						ISNULL(am_Comision, 0), 0, am_tarifa + ISNULL(am_iva, 0), NULL,
						ISNULL(am_TarifaContado, 0) + ISNULL(am_IvaContado, 0) + ISNULL(am_OtrosContado, 0),
						ISNULL(am_TarifaCredito, 0) + ISNULL(am_IvaCredito, 0) + ISNULL(am_OtrosCredito, 0),
						NULL, NULL, NULL,
						NULL, 1.0, NULL, @cur_id_sucursal, @cur_id_implante,
						@cur_id_FormasPago, @cur_cd_TarjetasCredito, @cur_iden_gds
					FROM dbo.ReservaGDS_Servicios
					WHERE id_reserva = @cur_id_reserva_int AND ISNULL(bl_anulado, 0) = 0
					*/
				END

				IF @@ERROR <> 0
					BREAK

				FETCH NEXT FROM cur_conceptos INTO @cur_cd_cliente, @cur_id_conceptofacturacion, @cur_in_nacionalidad, @cur_id_aerolinea, @cur_id_moneda, @cur_ds_paxname, @cur_ds_paxape, @cur_cd_paxtype, @cur_ds_paxClasificacion, @cur_cd_tiquete, @cur_dt_llegada, @cur_dt_salida, @cur_cd_cencosto, @cur_cd_auxiliar, @cur_cd_item, @cur_CodigoReserva, @cur_id_sucursal, @cur_id_implante, @cur_id_FormasPago, @cur_cd_TarjetasCredito, @cur_iden_gds, @cur_ColId, @cur_cd_Consecutivo_depende, @cur_cd_codigotc, @cur_ds_numerotc, @cur_ds_vencetc, @cur_ds_autorizaciontc, @cur_ds_vouchertc, @cur_in_cuotastc, @cur_id_FormasPagoTAO, @cur_cd_codigotcTAO, @cur_ds_numerotcTAO, @cur_ds_vencetcTAO, @cur_ds_autorizaciontcTAO, @cur_ds_vouchertcTAO, @cur_in_cuotastcTAO
			END
			CLOSE cur_conceptos
			DEALLOCATE cur_conceptos
			
			SET @msg = 'Conceptos Automaticos Generados Exitosamente'

			--SELECT *
			--	   ,ltrim(rtrim(@msg)) AS 'Respuesta'  
			--FROM #Concepto

			UPDATE c
			SET c.cd_cliente = NULL 
			from #Concepto c
			LEFT JOIN ConfiguracionConceptosAutoClientes ccac ON ccac.cd_cliente = c.cd_cliente
			WHERE ccac.id is NULL 

			Select @NumeroDecimales = 2
			From #Concepto c
			inner JOIN Configuracion_remisiones cr ON cr.id_cliente = c.cd_cliente
			where  bl_decimales_TAO_ConceptoAuto = 1


			INSERT INTO #GenerarConceptosAuto SELECT DISTINCT id_ConceptoFacturacion, cd_ConceptoFacturacion, ds_ConceptoFacturacion, id_TiposConceptFac, bl_contorlarCargImp, bl_CalculoAutoValoresFacturacion, id_TiposServicio, cd_TiposServicio, ds_TiposServicio, cd_proveedores, ds_proveedores, cd_tiquete, ds_servicio, ds_descrip, ds_paxname, ds_paxape, cd_paxtype, ds_paxClasificacion, in_nacionalidad, dt_llegada, dt_salida, cd_cencosto, cd_auxiliar, cd_item
			, Valor 
			, am_Contado 
			, am_Credito
			, ColId, cd_Consecutivo_depende, CodigoReserva, am_ImpuestoComision, Respuesta ,bl_RutaExentaIva --rgelis 2018/04/16 req.57446
			, id_FormasPago, id_TarjetasCredito --rgelis 2018/05/08 req.58559
			,am_basedescuento, am_pordescuento
			,id_FormasPagoAirPlus
            ,cd_FormasPagoAirPlus 
            ,ds_FormasPagoAirPlus
            ,id_TarjetasCreditoAirPlus
            ,cd_TarjetasCreditoAirPlus
            ,ds_numerotarjetaAirPlus
			,cd_codigotc 
			,ds_numerotc
			,ds_vencetc 
			,ds_autorizaciontc
			,ds_vouchertc 
			,in_cuotastc
			From(
				SELECT id_ConceptoFacturacion
					  ,cd_ConceptoFacturacion
					  ,ds_ConceptoFacturacion
					  ,id_TiposConceptFac
					  ,bl_contorlarCargImp
					  ,bl_CalculoAutoValoresFacturacion
					  ,id_TiposServicio
					  ,cd_TiposServicio
					  ,ds_TiposServicio
					  ,cd_proveedores
					  ,ds_proveedores
					  ,cd_tiquete
					  ,ds_servicio
					  ,ds_descrip
					  ,ds_paxname
					  ,ds_paxape
					  ,cd_paxtype
					  ,ds_paxClasificacion
					  ,in_nacionalidad
					  ,dt_llegada
					  ,dt_salida
					  ,cd_cencosto
					  ,cd_auxiliar
					  ,cd_item
					  ,Valor			
					  ,am_Contado = CASE
											WHEN id_FormasPago = 1 THEN valor 
											WHEN am_Contado<>0 AND am_Credito<>0 THEN valor --inicio rgelis 2017/02/11 req.47323
				  							WHEN am_Contado<>0 AND am_Credito=0  THEN valor
				  							ELSE 0 END 
					  ,am_Credito = CASE	WHEN id_FormasPago = 1 THEN 0
											WHEN id_formaspago_padre = 2 THEN valor
											WHEN am_Contado=0 AND am_Credito<>0 THEN valor
				  							ELSE 0 END --fin rgelis 2017/02/11 req.47323	
					  ,ColId
					  ,cd_Consecutivo_depende
					  ,CodigoReserva 
					  ,am_ImpuestoComision
					  ,Respuesta 
					  ,Id_moneda
					  ,id_conceptofacturacionOrigen
					  ,bl_RutaExentaIva --rgelis 2018/04/16 req.57446
					  ,CASE WHEN id_FormasPago = 1 THEN id_FormasPago ELSE NULL END AS 'id_FormasPago'
					  ,NULL  'id_TarjetasCredito'  
					  ,am_basedescuento, am_pordescuento
					  ,id_FormasPagoAirPlus
					  ,cd_FormasPagoAirPlus 
					  ,ds_FormasPagoAirPlus
					  ,id_TarjetasCreditoAirPlus
					  ,cd_TarjetasCreditoAirPlus
					  ,ds_numerotarjetaAirPlus
					  ,cd_codigotc 
					  ,ds_numerotc
					  ,ds_vencetc 
					  ,ds_autorizaciontc
					  ,ds_vouchertc 
					  ,in_cuotastc
				FROM(
					SELECT	cfa.id As 'id_ConceptoFacturacion',
							cfa.cd_codigo As 'cd_ConceptoFacturacion',
							cfa.ds_nombre As 'ds_ConceptoFacturacion',
							cfa.id_TiposConceptoFacturacion As 'id_TiposConceptFac',
							cfa.bl_contorlarCargImp,
							1 AS 'bl_CalculoAutoValoresFacturacion',
							ts.id As 'id_TiposServicio',
							ts.cd_codigo  As 'cd_TiposServicio',
							ts.ds_nombre  As 'ds_TiposServicio',
							cf.cd_proveedores,
							P.RAZONCIAL AS 'ds_proveedores',
							cf.cd_tiquete,
							cfa.ds_nombre As 'ds_servicio',
							cfa.ds_descrip AS 'ds_descrip',
							cf.ds_paxname,
							cf.ds_paxape,
							cf.cd_paxtype,
							cf.ds_paxClasificacion,
							cf.in_nacionalidad,
							cf.dt_llegada,
							cf.dt_salida,
							cd_cencosto = CASE WHEN @bl_utilizarcencostoimp = 1 AND ISNULL(I.cd_cencosto,'')<>'' THEN I.cd_cencosto WHEN @bl_utilizarcencostosuc = 1 AND ISNULL(S.cd_cencosto,'')<>'' THEN S.cd_cencosto ELSE cf.cd_cencosto END,
							cf.cd_auxiliar,
							cf.cd_item,
							Valor=ROUND((CASE WHEN ISNULL(CCC.am_valor,0)<>0 THEN ROUND(CCC.am_valor * CASE WHEN cf.id_moneda <>cc.id_moneda THEN  
																															case when MI.cd_codigo='USD' AND dbo.fnza_Valor_Parametro(424)='N' 
																															THEN @tasa_usd 
																															ELSE  dbo.fnza_Get_TasaCambioDia(@dt_fechaFactura,MI.id_monedaContabilidad) END 
																							 ELSE 1 END
																							 ,@NumeroDecimales) 
										   WHEN cc.bl_Valor=1 AND cc.am_Valor>0 THEN ROUND( cc.am_Valor * CASE WHEN cf.id_moneda <>cc.id_moneda THEN  
																															case when MI.cd_codigo='USD' AND dbo.fnza_Valor_Parametro(424)='N' 
																															THEN @tasa_usd 
																															ELSE  dbo.fnza_Get_TasaCambioDia(@dt_fechaFactura,MI.id_monedaContabilidad) END 
																							 ELSE 1 END
																							 ,@NumeroDecimales)--rgelis 2016/07/22 correccion por redondeo
										   WHEN cc.bl_porcentaje = 1 AND cc.am_porcentaje>0 AND cc.in_tipobasecalcular=0 THEN ROUND((cf.am_tarifa*(cc.am_porcentaje/100)),@NumeroDecimales,case when @TruncarDecimales = 'S' then 1 else 0 end)
										   WHEN cc.bl_porcentaje = 1 AND cc.am_porcentaje>0 AND cc.in_tipobasecalcular=1 THEN ROUND((cf.am_total*(cc.am_porcentaje/100)),@NumeroDecimales,case when @TruncarDecimales = 'S' then 1 else 0 end)
										   WHEN cc.in_tipobasecalcular= 2  THEN cf.am_ValorComision
										   WHEN cc.bl_porcentaje = 1 AND cc.am_porcentaje>0 AND cc.in_tipobasecalcular=3 THEN ROUND((cf.am_totalfactura*(cc.am_porcentaje/100)),@NumeroDecimales,case when @TruncarDecimales = 'S' then 1 else 0 end) 
										   WHEN	cc.bl_rango = 1 AND cc.in_tipobasecalcular=0 THEN dbo.fnza_ValorConceptoAutoRango(c.id,cc.id,cfa.id,cf.am_tarifa)
										   WHEN	cc.bl_rango = 1 AND cc.in_tipobasecalcular=1 THEN dbo.fnza_ValorConceptoAutoRango(c.id,cc.id,cfa.id,cf.am_total) 
										   ELSE 0 
									  END) / CASE WHEN cf.id_moneda <> @IdMonedaLocal AND cf.id_moneda <> cc.id_moneda AND dbo.fnza_Valor_Parametro(504)='S' AND cf.id_conceptofacturacion IN(1,2) AND ISNULL(cf.am_TasaCambio,0)<>0 THEN cf.am_TasaCambio ELSE 1 END --rgelis 2017/10/25/ req.54014
										   * CASE WHEN cf.id_moneda = @IdMonedaLocal AND cf.id_moneda <> cc.id_moneda AND cc.bl_rango = 1 AND ISNULL(@tasa_usd,0)>1 AND dbo.fnza_Valor_Parametro(504)<>'S' AND @PaisLocal='Colombia' THEN @tasa_usd ELSE 1 END,@NumeroDecimales),
							cf.ColId,
							cf.cd_Consecutivo_depende,
							cf.CodigoReserva, 
							am_ImpuestoComision = CASE WHEN cc.in_tipobasecalcular = 2 THEN cf.am_ImpuestoComision ELSE 0 END,
							cf.am_Contado, --rgelis 2017/02/11 req.47323
							cf.am_Credito, --rgelis 2017/02/11 req.47323 
							ltrim(rtrim(@msg)) AS 'Respuesta' ,
							cc.id_moneda,
							c.id_conceptofacturacion As 'id_conceptofacturacionOrigen',
							CASE WHEN c.id_conceptofacturacion IN (1,2) THEN dbo.fnza_RutaTktExentaIva(cf.ds_itinerario) ELSE 0 END AS 'bl_RutaExentaIva', --rgelis 2018/04/16 req.57446
							CFP.id_FormasPago,
							CFP.id_TarjetasCredito,
							CFP.ds_NumeroTarjetasCredito AS 'ds_NumeroTarjetasCredito',
							ISNULL(TC.ds_tcnumber,'') AS 'ds_NumeroTarjetasCreditoGDS',
							id_formaspago_padre = cf.id_formaspago,
							am_basedescuento = 	CASE 
													WHEN cc.bl_porcentaje = 1 AND cc.am_porcentaje>0 AND cc.in_tipobasecalcular=0 THEN cf.am_tarifa
													WHEN cc.bl_porcentaje = 1 AND cc.am_porcentaje>0 AND cc.in_tipobasecalcular=1 THEN cf.am_total
													ELSE 0
												END,
							am_pordescuento = CASE WHEN cc.bl_porcentaje = 1  THEN cc.am_porcentaje ELSE 0 END,
							id_FormasPagoAirPlus = CASE WHEN FPTAO.Id IS NOT NULL THEN FPTAO.Id
														WHEN tcA.Id IS NOT NULL AND cap.id IS NOT NULL THEN cap.Id_FormasPago ELSE NULL END,
							cd_FormasPagoAirPlus = CASE WHEN FPTAO.Id IS NOT NULL THEN FPTAO.cd_codigo
														WHEN tcA.Id IS NOT NULL AND cap.id IS NOT NULL THEN fpap.cd_codigo ELSE NULL END,
							ds_FormasPagoAirPlus = CASE  WHEN FPTAO.Id IS NOT NULL THEN FPTAO.ds_nombre
														WHEN tcA.Id IS NOT NULL AND cap.id IS NOT NULL THEN fpap.ds_nombre ELSE NULL END,
							id_TarjetasCreditoAirPlus = CASE WHEN FPTAO.Id IS NOT NULL AND tctao.id IS NOT NULL Then tctao.id
															 WHEN tcA.Id IS NOT NULL AND cap.id IS NOT NULL Then tcap.id ELSE NULL END,
							cd_TarjetasCreditoAirPlus = CASE WHEN FPTAO.Id IS NOT NULL AND tctao.id IS NOT NULL Then tctao.cd_codigo
															 WHEN tcA.Id IS NOT NULL AND cap.id IS NOT NULL Then tcap.cd_codigo ELSE NULL END,
							ds_numerotarjetaAirPlus = CASE WHEN FPTAO.Id IS NOT NULL AND tctao.id IS NOT NULL Then tkt.cd_NumeroTarjetaTAO
														   WHEN tcA.Id IS NOT NULL AND cap.id IS NOT NULL Then cap.ds_numerotarjeta ELSE NULL END,
							cd_codigotc = cf.cd_codigotc,
							ds_numerotc = cf.ds_numerotc,
							ds_vencetc = cf.ds_vencetc,
							ds_autorizaciontc = cf.ds_autorizaciontc,
							ds_vouchertc = cf.ds_vouchertc, 
							in_cuotastc = cf.in_cuotastc
					FROM dbo.ConfiguracionConceptosAutoClientes c
					INNER JOIN #Concepto cf ON (
												(
													ISNULL(cf.cd_cliente,'') = ISNULL(c.cd_cliente,'') 
													OR (ISNULL(c.cd_cliente,'')='' /*AND ISNULL(cf.cd_cliente,'')=''*/) 
												) 
												AND (
														ISNULL(cf.id_conceptofacturacion,0)=ISNULL(c.id_conceptofacturacion,0) 
														OR (ISNULL(c.id_conceptofacturacion,0)=0 AND ISNULL(cf.id_conceptofacturacion,0)=0)
													)
												AND (
														ISNULL(cf.id_tiposservicios,0)=ISNULL(c.id_tiposservicios,0) 
														OR ISNULL(c.id_tiposservicios,0)=0 --AND ISNULL(cf.id_tiposservicios,0)=0)
													) 
												AND (
														ISNULL(cf.in_nacionalidad,3)=ISNULL(c.in_nacionalidad,3) OR ISNULL(c.in_nacionalidad,3)=3
													)
												AND (
														ISNULL(cf.id_aerolinea,0)=ISNULL(c.id_Aerolinea,0) OR ISNULL(c.id_Aerolinea,0)=0
													)
												AND (
														ISNULL(cf.cd_tourcode,'')=ISNULL(c.cd_tourcode,'') OR ISNULL(c.cd_tourcode,'')=''
													)
												AND (
														ISNULL(cf.id_FormasPago,0)=ISNULL(c.id_formaspago,0) OR ISNULL(c.id_formaspago,0)=0
													)
												AND (
														ISNULL(cf.id_moneda,0)=ISNULL(c.id_moneda,0) OR ISNULL(c.id_moneda,0)=0
													)
												)
					LEFT JOIN dbo.TiposDocumento td ON td.id = cf.id_TiposDocumento --inicio rgelis 2017/09/19 req.52820
					LEFT JOIN dbo.ConfiguracionConceptosAutoClientes_Conceptos cc ON ((cc.id_ConfiguracionConceptosAutoClientes=c.id AND cc.bl_Activo = 1)
																					  AND ((c.id_conceptofacturacion IN (1,2) 
																							AND ((ISNULL(cf.cd_tktrevisado,'')<>'' AND cc.in_revisado=1) 
																								 OR (ISNULL(cf.cd_tktrevisado,'')='' AND cc.in_revisado=2) 
																								 OR cc.in_revisado in (0,3)
																								)
																							AND (((ISNULL(td.bl_EMD,0)=1 OR ISNULL(cf.cd_Penalidad,'')<>'' OR ISNULL(cf.cd_TipoTiqueteGDS,'') = 'EMD') AND cc.in_EMD=1) 
																								 OR ((ISNULL(td.bl_EMD,0)=0 AND ISNULL(cf.cd_Penalidad,'')='' AND ISNULL(cf.cd_TipoTiqueteGDS,'') <> 'EMD') AND cc.in_EMD=2) 
																								 OR cc.in_EMD in (0,3)
																								)
																							AND (((dbo.fnza_RutaTktExentaIva(cf.ds_itinerario)=1) AND cc.in_Exento=1) --inicio rgelis 2018/04/16 req.57446 
																								 OR ((dbo.fnza_RutaTktExentaIva(cf.ds_itinerario)=0) AND cc.in_Exento=2) 
																								 OR cc.in_Exento in (0,3)
																								) --fin rgelis 2018/04/16 req.57446 
																							AND (((dbo.fnza_ItinerarioTipo(cf.ds_itinerario)='OW') AND cc.in_Tipoitinerario=1 AND cc.bl_Tipoitinerario=1) --inicio --rgelis 2019/09/27 req.103215 
																								 OR ((dbo.fnza_ItinerarioTipo(cf.ds_itinerario)='RT') AND cc.in_Tipoitinerario=2 AND cc.bl_Tipoitinerario=1) 
																								 OR (cc.in_Tipoitinerario in (0,3) AND cc.bl_Tipoitinerario=1)
																								 OR cc.bl_Tipoitinerario=0
																								) --fin rgelis 2019/09/27 req.103215 	
																						   )
																						   OR c.id_conceptofacturacion NOT IN (1,2)
																						  )
																					   AND (
																							 (ISNULL(cc.id_sucursal,0) = ISNULL(cf.id_sucursal,0) or ISNULL(cc.id_sucursal,0) = 0)
																							 AND (ISNULL(cc.id_implante,0) = ISNULL(cf.id_implante,0) or ISNULL(cc.id_implante,0) = 0) 
																						   )
																					 ) --fin rgelis 2017/09/19 req.52820
					LEFT JOIN dbo.ConceptoFacturacion cfa ON cfa.id=cc.id_conceptofacturacion
					LEFT JOIN dbo.tiposServicio_asignados tsa ON (tsa.id_ConceptoFacturacion = cfa.id AND tsa.bl_Valdeft = 1) 
					LEFT JOIN dbo.TiposServicios ts ON ts.id = tsa.id_TipoServicio
					LEFT JOIN dbo.PROVEEDORES P ON P.IDPROVE = cfa.cd_proveedor
					LEFT JOIN dbo.Monedas_IATA MI ON MI.id = CC.id_moneda
					--LEFT JOIN dbo.ReservaGDS_Detalles rd on rd.ds_tkt_number = cf.cd_tiquete and cf.id_conceptofacturacion in (1,2)
					--LEFT JOIN dbo.TarjetasCredito TA ON TA.cd_codigo = CF.cd_TarjetasCredito
					OUTER APPLY dbo.fnza_ReservasGdsFormasPago_Table(cf.CodigoReserva,cf.cd_tiquete) AS TC
					LEFT JOIN dbo.ConfiguracioFacturaTarjetasPropias_NumerosTC CFP ON (CFP.ds_NumeroTarjetasCredito = tc.ds_tcnumber AND CFP.id_Sucursal = CF.id_sucursal AND ISNULL(CFP.id_implante,0) = ISNULL(CF.id_implante,0))
					--OUTER APPLY dbo.fnza_ReservasGdsFormasPago_Table(cf.CodigoReserva,cf.cd_tiquete) AS TC
					LEFT JOIN dbo.ConfiguracionClientesConceptos CCC ON CCC.id_conceptofacturacion=cc.id_conceptofacturacion AND CCC.Id_Cliente = c.cd_cliente AND CCC.bl_inactivo=0
					--LEFT JOIN dbo.ReservasGDS r ON r.cd_codigo = cf.CodigoReserva
					LEFT JOIN dbo.ReservaGDS_Detalles tkt ON tkt.ds_tkt_number = cf.cd_tiquete and cf.id_conceptofacturacion in (1,2)
					LEFT JOIN dbo.tarjetascredito tcA on tcA.cd_codigo = tkt.ds_cc_code AND (tcA.bl_airplus = 1 OR @bl_tomarFPAirplusTkt=1)
					LEFT JOIN dbo.Cliente_FP_AirPlus cap on cap.id_cliente = cf.cd_cliente
					LEFT JOIN dbo.tarjetascredito tcap on tcap.id=cap.Id_TarjetasCredito
					LEFT JOIN dbo.FormasPago fpap on fpap.id = cap.Id_FormasPago
					LEFT JOIN dbo.Sucursales S ON S.id = cf.id_sucursal
					LEFT JOIN dbo.Implantes I ON I.id=cf.id_implante
					LEFT JOIN dbo.FormasPago FPTAO ON FPTAO.cd_codigo=Tkt.cd_FormaPagoTAO AND @bl_tomarFPTaoTkt=1 
					LEFT JOIN dbo.tarjetascredito tctao on tctao.cd_codigo=tkt.cd_TarjetaCreditoTAO
					WHERE cc.id is NOT NULL 
					GROUP BY c.id,
							cc.id,
							cc.id_conceptofacturacion,
							cfa.id,
							cfa.id_TiposConceptoFacturacion,
							cfa.bl_contorlarCargImp,
							cf.cd_proveedores,
							P.RAZONCIAL,
							cf.cd_tiquete,
							cfa.cd_codigo,
							cfa.ds_nombre,
							cfa.ds_descrip,
							ts.id,
							ts.cd_codigo,
							ts.ds_nombre,
							cf.ds_paxname,
							cf.ds_paxape,
							cf.cd_paxtype,
							cf.ds_paxClasificacion,
							cf.in_nacionalidad,
							cf.dt_llegada,
							cf.dt_salida,
							cf.cd_cencosto,
							cf.cd_auxiliar,
							cf.cd_item,
							cf.am_tarifa,
							cf.am_total,
							cc.bl_Valor,
							cc.bl_porcentaje,
							cc.am_valor,
							cc.am_porcentaje,
							cc.bl_rango,
							cf.ColId,
							cc.bl_Activo,
							cc.in_tipobasecalcular,
							cf.cd_Consecutivo_depende,
							cf.CodigoReserva,
							cf.am_ValorComision,
							cf.am_ImpuestoComision,
							cf.am_totalfactura ,
							MI.id_monedaContabilidad  ,
							cc.id_moneda ,
							cf.id_moneda, 
							MI.cd_codigo,
							cf.am_Contado, --rgelis 2017/02/11 req.47323
							cf.am_Credito, --rgelis 2017/02/11 req.47323 
							cc.id_moneda,
							c.id_conceptofacturacion,
							cf.id_conceptofacturacion, --rgelis 2017/10/25 req.54014
							CF.am_TasaCambio, --rgelis 2017/10/25 req.54014
							cf.ds_itinerario, --rgelis 2018/04/16 req.57446
							CFP.id_FormasPago, --rgelis 2018/05/08 req.58559
							CFP.id_TarjetasCredito,
							CFP.ds_NumeroTarjetasCredito,
							TC.ds_tcnumber,
							cf.id_formaspago,
							CCC.am_valor,
							tcA.Id,
							cap.id,
							cap.Id_FormasPago, 
							fpap.cd_codigo,
							fpap.ds_nombre,
							tcap.id, 
							tcap.cd_codigo,
							cap.ds_numerotarjeta,
							S.cd_cencosto,
							I.cd_cencosto,
							FPTAO.Id,
							FPTAO.cd_codigo,
							FPTAO.ds_nombre,
							tctao.id,
							tctao.cd_codigo,
							tkt.cd_NumeroTarjetaTAO,
							cf.cd_codigotc,
							cf.ds_numerotc,
							cf.ds_vencetc,
							cf.ds_autorizaciontc,
							cf.ds_vouchertc, 
							cf.in_cuotastc
				) AS C
			 ) AS F			
			--------------------------------------------------------------------------
			
			
			--Determinando si se debe auditar el proceso exitoso
			/*IF (@bl_as = 1) 
			BEGIN 										
				EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
												 @id_usuario = @id_usuario ,
												 @cd_status  = 1           , 												 
												 @admsg      = NULL        ,
							 					 @msgparams  = @msg;
			END*/ 			 			
			--SELECT ltrim(rtrim(@msg)) AS 'Respuesta';
			RETURN @retval;
	    END TRY 
    
    	-- Bloque CATCH (Manejo de excepciones)
    	BEGIN CATCH 
 		
 			-- Tiempo de espera alcanzado --
		   IF ERROR_NUMBER() = 1222
		    BEGIN
      			SET @msg =  'No se pudo ejecutar el proceso. Tiempo de espera agotado.';
      			SET @retval = 1
      			
	   	        RAISERROR (@msg,16,125);
	   	       	--Se debe auditar proceso fallido
				/*IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce ,
													 			 @id_usuario = @id_usuario ,
													 			 @cd_status  = 0           , 
													 			 @admsg      = @msg	   ;*/				
	   	       RETURN @retval;
		    END
		    
		    -- Registro bloqueado / Conflicto de actualizacion
		    ELSE IF ERROR_NUMBER() IN (1205, 3960)
    		BEGIN	   	        
		       	SET @retry     = 1              ;
		       	SET @retrycont = @retrycont + 1 ; 

	    	 END
	    	 ELSE
		     BEGIN
		     	-- Error no manejado --
				IF (XACT_STATE() <> 0)
	   	        BEGIN 				
					SET @retval = 1;
  	 				SET @msg =	'Ha ocurrido un error. InformaciÃ³n para soporte tecnico:'			+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							    'Numero: ' + isnull(CAST(ERROR_NUMBER()   AS VARCHAR(10)),'') 		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
								'Mensaje: ' + isnull(ERROR_MESSAGE(),'') 					   		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							 	'Severidad: ' + isnull(CAST(ERROR_SEVERITY() AS VARCHAR(10)),'') 	+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							 	'Estado: ' + isnull(CAST(ERROR_STATE()    AS VARCHAR(10)),'') 		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
								'Procedimiento: ' + 'spza_GenerarConceptosAutoJOB_Consultar'		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
								'Linea: ' + isnull(CAST(ERROR_LINE() 	   AS VARCHAR(10)),''); 							
		
					RAISERROR (@msg,16,126);
					--Se debe auditar proceso fallido
					/*IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar	@id_proceso = @idproce   ,
											 			 			@id_usuario = @id_usuario ,
											 			 			@cd_status  = 0           , 
											 			 			@admsg      = @msg	  ;*/				
					RETURN @retval;
	   	        END 
		     END
		END CATCH     
	END 
	
	IF (@retrycont>@maxretries) 
	BEGIN 
		SET @retval = 1
		SET @msg = 'No se pudo finalizar el proceso. Maximo numero de reintentos alcanzado.'
		--Se debe auditar proceso fallido
		/*IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
											 			 @id_usuario = @id_usuario ,
											 			 @cd_status  = 0           , 
											 			 @admsg      = @msg	   ;*/												 	   					   
  		RAISERROR (@msg,16,127);
  		RETURN @retval;
  	END   	
    
    RETURN @retval;
END
GO



GO

IF OBJECT_ID('dbo.spza_GestionJob', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spza_GestionJob;
GO

CREATE PROCEDURE [dbo].[spza_GestionJob] 
	-- Parametros del procedimiento --
	  @id_usuario   INT	
	, @op			VARCHAR(50)	= NULL
	, @NombresZxml  VARCHAR(MAX)= NULL
	, @Id			INT			= NULL
 
AS
BEGIN
	-- SET NOCOUNT ON: Previene que conjuntos de resultados extras interfieran con 
	-- expresiones SELECT
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

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
			@retval		TINYINT 		, -- Valor de retorno de este procedimiento: 0:Exito ; 1:Error(Bloque Catch)
			@errmsg	    VARCHAR(max)    ; -- Mensaje de error			
	
	SELECT 	@idproce 			 = CASE @op WHEN 'Crear'		THEN 596
											WHEN 'Iniciar'		THEN 597
											WHEN 'Detener'		THEN 598 
											WHEN 'Habilitar'	THEN 599	
											WHEN 'Deshabilitar' THEN 600
											WHEN 'Eliminar'     THEN 601
											ELSE -1 
								   END,
			@retry				 = 1  ,
			@retrycont			 = 0  ,
			@retval              = 0  ;
	
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
				SELECT 'No posee permisos suficientes para ejecutar esta accion.' AS 'Respuesta', 1 AS 'Estado'
				SET @retval = 1;
				RETURN @retval;
			END 
			
			--Iniciando / salvando transaccion dependiendo si ya esta iniciada o no--
		  	BEGIN TRAN;
			
			--Instrucciones del procedimiento-----------------------------------------
			IF @Op = 'ValidarPermisos'
			BEGIN 
				SELECT
					  sp.name AS principal_name
					, sp.type_desc AS principal_type
					, spr.name AS security_entity
					, 'role membership' AS security_type
					, NULL AS state_desc
				FROM sys.server_principals AS sp
					INNER JOIN sys.server_role_members AS srm
						ON sp.principal_id = srm.member_principal_id
					INNER JOIN sys.server_principals spr
						ON srm.role_principal_id = spr.principal_id
				WHERE sp.type IN ('s', 'u')
					AND sp.name = SUSER_SNAME() 
			END	
	
		--IF @@TRANCOUNT = 0 BEGIN BEGIN TRANSACTION SET @SwCommit=1 END
			IF @@version like '%Express%'
			BEGIN
				if @Op <> 'Campos'
				begin
					IF (@@TRANCOUNT > 0)
					BEGIN 
						ROLLBACK TRAN;
					END
					RAISERROR( 'Esta opcion no funciona en version ''Express''', 16 , 1 )
				end
			END
			
			-------------------------------------------------------------------
			-- Declaracion y Asignacion de Variables
			-------------------------------------------------------------------
			declare @ds_NombreJob varchar (128)
			declare @Job_Owner sysname
			declare @enum_job table ( Job_ID uniqueidentifier, Last_Run_Date int, Last_Run_Time int, Next_Run_Date int, Next_Run_Time int, Next_Run_Schedule_ID int, Requested_To_Run int, Request_Source int, Request_Source_ID varchar(100), Running int, Current_Step int, Current_Retry_Attempt int, State int )       
			
			Select @ds_NombreJob = ds_NombreJob + '_' + db_name () 
			From GestionJob where Id = @Id
				
					
			set @Job_Owner = SUSER_SNAME()
			
			If @Op in ( 'Iniciar', 'Detener', 'Habilitar', 'Deshabilitar', 'Eliminar' )
			Begin
			
				insert @enum_job
				exec master.dbo.xp_sqlagent_enum_jobs 1, @job_owner
				
				IF @@ROWCOUNT = 0 
				BEGIN
					IF (@@TRANCOUNT > 0)
					BEGIN 
						ROLLBACK TRAN;
					END
					RAISERROR('No se ha completado la accion, el SQLServerAgent no esta¡ en ejecucion.',16,1)
					RETURN -1
				END
				
			End
			
			-------------------------------------------------------------------
			-- Operaciones.
			-------------------------------------------------------------------
			If @Op = 'Actualizar'
			Begin
				Select GestionJob.Id
					, NombreJob.Nombre as ds_NombreJob
					, Case
						When SysJobs.enabled IS NULL THEN 'No estÃƒÂ¡ en la base'
						When isnull ( SysJobs.enabled, 0 ) = 0 then 'Deshabilitado'
						When isnull ( SysJobs.enabled, 0 ) = 1 AND isnull ( JobsEnEjecucion.name, '' ) = '' THEN 'No estÃƒÂ¡ en ejecuciÃƒÂ³n'
						Else 'Ejecutando'
					  End As ds_Estado
					, ' ' As ds_Accion
					, GestionJob.ds_TiempoEspera As ds_TiempoEspera
				From GestionJob
					Cross Apply(
						Select GestionJob.ds_NombreJob + '_' + db_name () As Nombre
					) As NombreJob
					left join msdb.dbo.sysjobs SysJobs 
						ON NombreJob.Nombre = SysJobs.name COLLATE DATABASE_DEFAULT
					left JOIN ( 
							SELECT job.name
							FROM msdb.dbo.sysjobs_view job
								JOIN msdb.dbo.sysjobactivity activity 
									ON job.job_id = activity.job_id
								JOIN msdb.dbo.syssessions sess 
									ON sess.session_id = activity.session_id
								JOIN (
									SELECT MAX( agent_start_date ) AS max_agent_start_date
									FROM msdb.dbo.syssessions
								) As sess_max
									ON sess.agent_start_date = sess_max.max_agent_start_date
							WHERE run_requested_date IS NOT NULL AND stop_execution_date IS NULL 
						) JobsEnEjecucion 
							On SysJobs.name = JobsEnEjecucion.name
			End
			--------------------------------------------------------------------
			if @Op = 'Campos'
			begin
				select	0 As id
					, '' As ds_NombreJob
					, '' As ds_Estado
					, ' ' As ds_Accion
					, 0 As ds_TiempoEspera
			end
			--------------------------------------------------------------------
			if @Op = 'Guardar'
			begin
			
				-------------------------------------------------------------------
				-- Declaracion y Asignacion de Variables
				-------------------------------------------------------------------
				Declare @GestionJob table (id INT,ds_NombreJob varchar ( 128 ), ds_Estado varchar( 50 ), ds_Accion varchar ( 50 ), ds_TiempoEspera Numeric )
				Declare
					  @numAux1 numeric
					, @numAux2 numeric
					, @ds_Accion varchar(50)
					, @ds_TiempoEspera numeric
					, @ds_Valor varchar(100)
				
				Insert @GestionJob 
				Exec SpZml @NombresZxml
				
				delete @GestionJob where ds_Accion = ' '

				UPDATE G
				SET G.ds_TiempoEspera=TG.ds_TiempoEspera
				FROM dbo.GestionJob G
				INNER JOIN @GestionJob TG ON TG.id=G.id
				
				-------------------------------------------------------------------
				-- Operaciones.
				-------------------------------------------------------------------
				Select
					  @numAux1 = Min( [@GestionJob].Id )
					, @numAux2 = Max( [@GestionJob].Id )				
				From @GestionJob
				
				While @numAux1 <= @numAux2
				Begin
					Select	
						  @id 				= [@GestionJob].Id
						, @ds_Accion		= [@GestionJob].ds_Accion	
						, @ds_TiempoEspera 	= Convert(Numeric,ISNULL(GestionJob.ds_TiempoEspera,0))
					From @GestionJob 
						Join GestionJob 
							On [@GestionJob].Id = GestionJob.Id	
					Where [@GestionJob].Id = @numAux1				
					
					
					Exec [Spza_GestionJob] @id_usuario=@id_usuario, @Op = @ds_Accion, @Id = @Id
					
					Set @numAux1 = @numAux1 + 1
				End	
			End
			--------------------------------------------------------------------
			if @Op = 'Crear'
			begin
				EXEC Spza_GestionJob_CrearJob @id_usuario=@id_usuario, @id=@Id
			end
			--------------------------------------------------------------------
			if @Op = 'Iniciar'
			begin
				-------------------------------------------------------------------
				-- Operaciones.
				-------------------------------------------------------------------	
				IF Not Exists ( Select 1 From @enum_job e inner join msdb.dbo.sysjobs j on e.job_id = j.job_id Where j.name COLLATE DATABASE_DEFAULT = @ds_NombreJob And e.state = 1)
				BEGIN
					If Exists ( Select 1 From @enum_job e inner join msdb.dbo.sysjobs j on e.job_id = j.job_id Where j.name COLLATE DATABASE_DEFAULT = @ds_NombreJob And j.enabled = 1 )
					begin
						Exec msdb.dbo.sp_start_job @job_name = @ds_NombreJob
						WaitFor Delay '00:00:1'
					end
				END
			end
			--------------------------------------------------------------------
			if @Op = 'Detener'
			begin
				-------------------------------------------------------------------
				-- Operaciones.
				-------------------------------------------------------------------
				If Exists ( Select 1 From @enum_job e inner join msdb.dbo.sysjobs j on e.job_id = j.job_id Where j.name COLLATE DATABASE_DEFAULT = @ds_NombreJob And j.enabled = 1 AND e.state = 1 )
				begin
					EXEC msdb.dbo.sp_stop_job @Job_Name = @ds_NombreJob
				end
			end
			--------------------------------------------------------------------
			if @Op = 'Habilitar'
			begin
				-------------------------------------------------------------------
				-- Operaciones.
				-------------------------------------------------------------------
				If Exists ( Select 1 From @enum_job e inner join msdb.dbo.sysjobs j on e.job_id = j.job_id Where j.name COLLATE DATABASE_DEFAULT = @ds_NombreJob And j.enabled = 0 )
				begin
					EXEC msdb.dbo.sp_update_job @Job_Name = @ds_NombreJob, @enabled = 1
				end
			end
			--------------------------------------------------------------------
			if @Op = 'Deshabilitar'
			begin
				-------------------------------------------------------------------
				-- Operaciones.
				-------------------------------------------------------------------
				If Exists ( Select 1 From @enum_job e inner join msdb.dbo.sysjobs j on e.job_id = j.job_id Where j.name COLLATE DATABASE_DEFAULT = @ds_NombreJob And j.enabled = 1 )
				begin
					EXEC msdb.dbo.sp_update_job @Job_Name = @ds_NombreJob, @enabled = 0
				end
			end
			--------------------------------------------------------------------
			if @Op = 'Eliminar'
			begin
				-------------------------------------------------------------------
				-- Operaciones.
				-------------------------------------------------------------------
				If Exists ( Select 1 From @enum_job e inner join msdb.dbo.sysjobs j on e.job_id = j.job_id Where j.name COLLATE DATABASE_DEFAULT = @ds_NombreJob )
				begin
					EXEC msdb.dbo.sp_delete_job @Job_Name = @ds_NombreJob
				end
			end
			--------------------------------------------------------------------------
			IF (XACT_STATE() <> 0) and (@@TRANCOUNT > 0) 
		   	BEGIN 
			   COMMIT TRAN;				   
			END	
			RETURN @retval;
	    END TRY 
    
    	-- Bloque CATCH (Manejo de excepciones)
	BEGIN CATCH 
 		
 			-- Tiempo de espera alcanzado --
		    IF ERROR_NUMBER() = 1222
		    BEGIN
      			SET @msg =  'No se pudo ejecutar el proceso. Tiempo de espera agotado.';
      			SET @retval = 1
      			
      			IF (@@TRANCOUNT > 0)
				BEGIN 
					ROLLBACK TRAN;
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
		    ELSE 
		    IF ERROR_NUMBER() IN (1205, 3960)
    		BEGIN
    		
    			IF (@@TRANCOUNT > 0)
				BEGIN 
					ROLLBACK TRAN;
				END
	   	        
		       	SET @retry     = 1              ;
		       	SET @retrycont = @retrycont + 1 ; 
	   	 	END
	    	ELSE
		    BEGIN
		     	-- Error no manejado --					
				IF (@@TRANCOUNT > 0)
				BEGIN 
					ROLLBACK TRAN;
				END	
													
				SET @retval = 1;
 				SET @msg =	'Ha ocurrido un error. Informacion para soporte tecnico:'			+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
						    'Numero: ' + isnull(CAST(ERROR_NUMBER()   AS VARCHAR(10)),'') 		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							'Mensaje: ' + isnull(ERROR_MESSAGE(),'') 					   		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
						 	'Severidad: ' + isnull(CAST(ERROR_SEVERITY() AS VARCHAR(10)),'') 	+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
						 	'Estado: ' + isnull(CAST(ERROR_STATE()    AS VARCHAR(10)),'') 		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							'Procedimiento: ' + isnull(ERROR_PROCEDURE(),'')					+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							'Linea: ' + isnull(CAST(ERROR_LINE() 	   AS VARCHAR(10)),'')      + CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) ; 							
	
				--Se debe auditar proceso fallido
				IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar	@id_proceso = @idproce   ,
										 			 			@id_usuario = @id_usuario ,
										 			 			@cd_status  = 0           , 
										 			 			@admsg      = @msg	  ;	
				RAISERROR (@msg,16,126);
				--SELECT @msg AS 'Respuesta', 1 AS 'Estado';
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

IF OBJECT_ID('dbo.spza_GestionJob_CrearJob', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spza_GestionJob_CrearJob;
GO

CREATE PROCEDURE [dbo].[spza_GestionJob_CrearJob] 
	-- Parametros del procedimiento
	@id_usuario 	INT , -- Id de Usuario
	@id				INT  

 
AS
BEGIN
	-- SET NOCOUNT ON: Previene que conjuntos de resultados extras interfieran con 
	-- expresiones SELECT
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

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
	
	SELECT 	@idproce 			 = 596,
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
			DECLARE
				  @nameJob NVARCHAR(255)
				, @dataBase NVARCHAR(255)
				, @procedure NVARCHAR(255)
				, @descrip nvarchar(255)
				, @category_name NVARCHAR(255)
				, @id_Job Binary(16)
			IF @Id IS NULL
			BEGIN
				RAISERROR('No se especificó el job a crear.',16,1)
				RETURN -1
			END
			
			IF NOT EXISTS(SELECT 1 FROM dbo.GestionJob WHERE Id = @Id)
			BEGIN
				RAISERROR('El job especificado no esta definido en el sistema.',16,1)
				RETURN -1
			END
    	    		
    		--Obteniendo informacion de seguridad y auditoria--
			EXEC dbo.spzaProcesoUsuario_Consultar @id_usuario   = @id_usuario       ,
												  @id_proceso   = @idproce 		    , 
												  @bl_permit    = @bl_permit OUTPUT , 
												  @bl_auditsuc  = @bl_as 	 OUTPUT , 
												  @bl_auditfail = @bl_af 	 OUTPUT ;
			IF (@bl_permit = 0)
			BEGIN 
				SELECT 'No posee permisos suficientes para ejecutar esta acción.' AS 'Respuesta', 1 AS 'Estado'
				RETURN @retval;
			END 
			
			--Iniciando / salvando transaccion dependiendo si ya esta iniciada o no--
		  	BEGIN TRAN;
		  	
		
			SELECT @category_name = N'ZeusAgenciasMinoristaSQL'
				, @dataBase = db_name()
				 			
			--Instrucciones del procedimiento----------------------------------------
			--Se define el nombre del job a crear y el procedimiento a ejecutar
			SELECT 
				  @nameJob = 	GestionJob.ds_NombreJob + '_' + db_name()
				, @procedure = N'Exec ' + GestionJob.ds_Procedimiento
				, @descrip = GestionJob.ds_Descripcion
			FROM dbo.GestionJob
			WHERE GestionJob.Id = @Id
								
			IF NOT EXISTS(SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @namejob)
			BEGIN
				IF NOT EXISTS(
					SELECT name 
					FROM msdb.dbo.syscategories 
					WHERE name=@category_name and category_class = 1)
				BEGIN
					EXEC msdb.dbo.sp_add_category @class=N'JOB', @type=N'Local', @name=@category_name
				END
				
				Exec msdb.dbo.sp_add_job 
						@job_name = @nameJob, 
						@enabled = 1, 
						@notify_level_eventlog=0, 
						@notify_level_email=2, 
						@notify_level_netsend=2, 
						@notify_level_page=2, 
						@delete_level=0, 
						@description = @descrip, 
						@category_name = @category_name, 
						@owner_login_name = N'sa',
						@job_id = @id_Job output
				
				Exec msdb.dbo.sp_add_jobstep 
						@job_id = @id_Job, 
						@step_name = N'Ejecutar', 
						@step_id = 1, 
						@cmdexec_success_code = 0, 
						@on_success_action = 3, 
						@on_fail_action=3, 
						@retry_attempts=0, 
						@retry_interval=0, 
						@os_run_priority=0, 
						@subsystem = N'TSQL', 
						@command = @procedure, 
						@database_name = @dataBase, 
						@flags=0
				
				Exec msdb.dbo.sp_add_jobstep 
						@job_id=@id_Job, 
						@step_name=N'Volver_A_Ejecutar',
						@step_id=2, 
						@cmdexec_success_code=0, 
						@on_success_action=4, 
						@on_success_step_id=1, 
						@on_fail_action=4, 
						@on_fail_step_id=1, 
						@retry_attempts=0, 
						@retry_interval=0, 
						@os_run_priority=0, 
						@subsystem=N'TSQL', 
						@database_name = @dataBase, 
						@flags=0

				exec msdb.dbo.sp_update_job 
						@job_id = @id_Job, 
						@start_step_id = 1

				exec msdb.dbo.sp_add_jobschedule 
						@job_id=@id_Job, 
						@name=N'Iniciar', 
						@enabled=1, 
						@freq_type=64, 
						@freq_interval=0, 
						@freq_subday_type=0, 
						@freq_subday_interval=0, 
						@freq_relative_interval=0, 
						@freq_recurrence_factor=0, 
						@active_start_date=20090101, 
						@active_end_date=99991231, 
						@active_start_time=0, 
						@active_end_time=235959

				exec msdb.dbo.sp_add_jobserver 
						@job_id = @id_Job, 
						@server_name = N'(Local)'
			END			
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
			
			--SELECT ltrim(rtrim(@msg)) AS 'Respuesta', 0 AS 'Estado' ;
			RETURN @retval;
	    END TRY 
    
    	-- Bloque CATCH (Manejo de excepciones)
		BEGIN CATCH 
 		
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
 				SET @msg =	'Ha ocurrido un error. Información para soporte tecnico:'			+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
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

IF OBJECT_ID('dbo.spza_Get_GDSFacturacionAutoJOB_ItinerarioAerolinea', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spza_Get_GDSFacturacionAutoJOB_ItinerarioAerolinea;
GO
CREATE PROCEDURE dbo.spza_Get_GDSFacturacionAutoJOB_ItinerarioAerolinea 
	-- Parametros del procedimiento
	@id_usuario INT,
	@cd_sucursal VARCHAR(MAX) = '',
	@cd_implante VARCHAR(MAX) = '' 

 
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
			@tc			INT 			, -- Numero de transacciones abiertas
			@msg	    VARCHAR(8000)   , -- Mensaje retornado por el sistema
			@retval		TINYINT 		, -- Valor de retorno de este procedimiento: 0:Exito ; 1:Error(Bloque Catch)
			@bl_tomarvendedorcliente BIT, -- Filtro para tomar vendedor del cliente /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
			@bl_GenerarFacturaXTiquete BIT,
			@FiltrarSucursalFactAuto BIT;
	
	SELECT 	@idproce 			 = 123,
			@retry				 = 1 		   ,
			@retrycont			 = 0		   ,
			@tc 			 	 = @@TRANCOUNT ,
			@retval				 = 0;
  	
  	-- Manejo de tiempo de espera y de reintentos por bloqueo de tablas/registros  
   	SELECT @maxretries = 3
	SELECT @timeout    = 3000
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
			
	   
			--Instrucciones del procedimiento-----------------------------------------

			--CREATE TABLE #TablaReservas(Id INT IDENTITY,Id_ReservasGDS INT, id_ReservaGDS_Detalles INT, ds_ItinerarioAerolinea VARCHAR(128)) 
			DECLARE @MAXTablaReservas INT, @I INT, @Id_Reserva INT, @Id_ReservaGdsDetalle INT, @Result VARCHAR(128), @ItinerarioInicio VARCHAR(128), @ItinerarioFin VARCHAR(128), 
				@ItinerarioReserva VARCHAR(128), @ItinerarioTkt VARCHAR(128)
			DECLARE @TableItinerario  TABLE(Id INT IDENTITY, Itinerario VARCHAR(3), Itinerariofin VARCHAR(3)) 
			DECLARE @TableItinerarioFin TABLE(Id INT IDENTITY, Itinerario VARCHAR(3)) 
			SET @Result=''
			SET @FiltrarSucursalFactAuto = 0;
			SELECT @FiltrarSucursalFactAuto = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=426 /*JARG 2015/07/25 - filtrar por sucursal facturacion automatica -M&M*/
	
			--Obtenemos las reservas de detalle
			INSERT INTO #TablaReservas(Id_ReservasGDS, id_ReservaGDS_Detalles, ds_ItinerarioAerolinea)
			SELECT R.id,tkt.id,''
			FROM dbo.ReservasGDS As R
			INNER JOIN dbo.ReservasGDS_FacAuto fpa ON fpa.id_reserva = r.id
			INNER JOIN dbo.ReservaGDS_Detalles tkt ON tkt.id_reserva=R.id
			WHERE tkt.bl_usada = 0 AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_sucursal, ',', 0, 1) s WHERE s.Codigo = fpa.cd_sucursal) OR ISNULL(@cd_sucursal,'')='' OR @FiltrarSucursalFactAuto = 0)

			SELECT @MAXTablaReservas=COUNT(*),@I=1 FROM #TablaReservas

			WHILE @I <= @MAXTablaReservas 
			BEGIN
				--Obtenemos el Id de la reserva			
				SELECT @Id_Reserva = Id_ReservasGDS
						,@Id_ReservaGdsDetalle = id_ReservaGDS_Detalles	 
				FROM #TablaReservas WHERE id=@I
			
				--Obtenemos el itinerario del tkt
				SELECT
					@ItinerarioReserva = Case when ReservasGDS.iden_gds = 2 then ReservasGDS.ds_itinerario 
											  When isnull(ReservaGDS_Detalles.ds_itinerario,'') <> '' Then ReservaGDS_Detalles.ds_itinerario 
											  Else dbo.fnza_Get_ReservaItinerarioSobrante (ReservasGDS.Id,ReservaGDS_Detalles.Id) End
				FROM dbo.ReservasGDS
				INNER JOIN ReservaGDS_Detalles ON ReservaGDS_Detalles.id_reserva = ReservasGDS.id
				WHERE ReservaGDS_Detalles.id=@Id_ReservaGdsDetalle

				Set @ItinerarioTkt = @ItinerarioReserva

				SELECT @ItinerarioReserva=REPLACE(@ItinerarioReserva,'/ /','/')
				--llenamos las Variables que se usan como puente para el itinerario
				SELECT @ItinerarioInicio = LEFT(@ItinerarioReserva,LEN(@ItinerarioReserva)-4)
				SELECT @ItinerarioFin=RIGHT(@ItinerarioReserva,LEN(@ItinerarioReserva)-4)
			
				--Insetamos la parte inicial de los itinerarios
				DELETE FROM @TableItinerario

				DECLARE @Str VARCHAR(MAX), @Pos INT
				SET @Str = @ItinerarioInicio
				WHILE CHARINDEX('/', @Str) > 0
				BEGIN
					SET @Pos = CHARINDEX('/', @Str)
					INSERT INTO @TableItinerario (Itinerario) VALUES (LTRIM(RTRIM(LEFT(@Str, @Pos - 1))))
					SET @Str = SUBSTRING(@Str, @Pos + 1, LEN(@Str))
				END
				IF LEN(@Str) > 0
					INSERT INTO @TableItinerario (Itinerario) VALUES (LTRIM(RTRIM(@Str)))
			
				--Insetamos la parte Final de los itinerarios
				DELETE FROM @TableItinerarioFin
		
				SET @Str = @ItinerarioFin
				WHILE CHARINDEX('/', @Str) > 0
				BEGIN
					SET @Pos = CHARINDEX('/', @Str)
					INSERT INTO @TableItinerarioFin (itinerario) VALUES (LTRIM(RTRIM(LEFT(@Str, @Pos - 1))))
					SET @Str = SUBSTRING(@Str, @Pos + 1, LEN(@Str))
				END
				IF LEN(@Str) > 0
					INSERT INTO @TableItinerarioFin (itinerario) VALUES (LTRIM(RTRIM(@Str)))
			
				--Actualizamos para que quede armado el itinerario
				UPDATE t
				SET itinerariofin = t2.itinerario
				FROM @TableItinerario t
				INNER JOIN @TableItinerarioFin t2 ON t2.id = t.id
			
				--Obtenemos el itinerario por aerolinea cruzando con la ruta y reserva
				SET @Result=''

				Select @Result = @Result + cd_aero_siglas + '/' 
				FROM ReservaGDS_Itinerarios
				INNER JOIN @TableItinerario ti ON (ti.itinerario = cd_origen AND ti.itinerariofin = cd_destino)
				WHERE id_reserva = @Id_Reserva AND cd_aero_siglas IS NOT NULL 
		
				/*inicio rgelis 2013/09/13 sa cambia porque cuando pasa mas de 47 carateres se desborda en la factura de tiquetes*/
				--UPDATE #TablaReservas 
				--SET ds_ItinerarioAerolinea = LEFT(@Result,LEN(@Result)-1)
				--WHERE Id=@I
				UPDATE #TablaReservas 
				SET ds_ItinerarioAerolinea = CASE WHEN LEN(@Result)>47 THEN LEFT(@Result,47)
			 										WHEN LEN(@Result)>1 THEN LEFT(@Result,LEN(@Result)-1)
													ELSE @Result END
				WHERE Id=@I	AND LTRIM(ISNULL(@Result,''))<>''
				/*fin rgelis 2013/09/13 sa cambia porque cuando pasa mas de 47 carateres se desborda en la factura de tiquetes*/
			
				SET @I = @I + 1	
			END

			--Determinando si se debe auditar el proceso exitoso
			IF (@bl_as = 1) 
			BEGIN 										
				EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
												 @id_usuario = @id_usuario ,
												 @cd_status  = 1           , 												 
												 @admsg      = NULL        ,
							 					 @msgparams  = @msg;
			END 			 			
			
						
			RETURN @retval;
	    END TRY 
    																																			  
    	BEGIN CATCH 
    	-- Bloque CATCH (Manejo de excepciones)
 		
 			-- Tiempo de espera alcanzado --
		    IF ERROR_NUMBER() = 1222
		    BEGIN
      			SET @msg =  'No se pudo ejecutar el proceso. Tiempo de espera agotado.';
      			SET @retval = 1
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
	   	        
		       	SET @retry     = 1              ;
		       	SET @retrycont = @retrycont + 1 ; 

	    	 END
	    	 ELSE
		     BEGIN
		     	-- Error no manejado --
				IF (XACT_STATE() <> 0)
	   	        BEGIN 
														
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


GO

IF OBJECT_ID('dbo.spza_ReservasGDS_FEEJOB_Consultar', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spza_ReservasGDS_FEEJOB_Consultar;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE Procedure [dbo].[spza_ReservasGDS_FEEJOB_Consultar]
	@Id_Reservas Varchar(8000)
 
AS
BEGIN
	-- SET NOCOUNT ON: Previene que conjuntos de resultados extras interfieran con 
	-- expresiones SELECT
	SET NOCOUNT ON;
		
	SELECT 
		 F.id_reserva
		,cd_tiquete=CASE WHEN LEN(F.cd_tiquete)>=13 THEN RIGHT(F.cd_tiquete,LEN(F.cd_tiquete)-3) ELSE F.cd_tiquete END
		,F.in_orden
		,F.cd_conceptofac
		,F.cd_subcodigo
		,F.am_valor
		,ISNULL(F.ds_servicio,'') AS ds_servicio
	FROM dbo.ReservaGDS_FEE AS F  
	INNER JOIN dbo.fnSplit(@Id_Reservas,',',0,1) AS R ON R.Codigo=F.id_reserva
	
END


GO

IF OBJECT_ID('dbo.spza_ReservasGDSJOB_CargosImpuestos', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spza_ReservasGDSJOB_CargosImpuestos;
GO
CREATE PROCEDURE [dbo].[spza_ReservasGDSJOB_CargosImpuestos] 

	@id_reservas 	VARCHAR(8000)

 
AS
BEGIN
			SET NOCOUNT ON;
			DECLARE @Tabla TABLE(id_Reserva INT,GDS VARCHAR(MAX),Iden_GDS INT)
			INSERT INTO @Tabla(id_Reserva,GDS,Iden_GDS) 
			SELECT r.id AS id_Reserva, r.reserva AS  GDS , r.iden_gds
			FROM dbo.ReservasGDS r
			INNER JOIN dbo.fnSplitMejorado(@id_reservas,',',0,1) AS s ON CONVERT(INT,s.Codigo) = r.id

			SELECT 
				r.id,
				r.id_reserva,
				ISNULL(r.id_reservaGDS_detalles,0) AS id_reservaGDS_detalles,
				ISNULL(r.id_reservaGDS_servicios,0) AS id_reservaGDS_servicios,
				r.in_orden,
				r.cd_codigo,
				r.ds_nombre,
				r.cd_tipo,
				ISNULL(r.cd_codigopadre,'') AS cd_codigopadre,
				ISNULL(r.cd_tipopadre,'') AS cd_tipopadre,
				ISNULL(r.am_porcentaje,0) AS am_porcentaje,
				am_contado = r.am_contado * CASE WHEN r.cd_tipo IN('2','4') THEN -1 ELSE 1 END,
				am_credito = r.am_credito * CASE WHEN r.cd_tipo IN('2','4') THEN -1 ELSE 1 END,
				am_valor= r.am_valor * CASE WHEN r.cd_tipo IN('2','4') THEN -1 ELSE 1 END
			FROM dbo.ReservaGDS_CargosImpuestos r
			INNER JOIN @Tabla t ON t.id_Reserva = r.id_reserva
			ORDER BY r.id_reservaGDS_detalles,r.id_reservaGDS_servicios,r.in_orden



END


GO

IF OBJECT_ID('dbo.spza_ReservasGDSJOB_FormasPagos', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spza_ReservasGDSJOB_FormasPagos;
GO
CREATE PROCEDURE [dbo].[spza_ReservasGDSJOB_FormasPagos] 

	@id_reservas 	VARCHAR(8000)

 
AS
BEGIN
			SET NOCOUNT ON;
			DECLARE @Tabla TABLE(id_Reserva INT,GDS VARCHAR(MAX),Iden_GDS INT)
			INSERT INTO @Tabla(id_Reserva,GDS,Iden_GDS) 
			SELECT r.id AS id_Reserva, r.reserva AS  GDS , r.iden_gds
			FROM dbo.ReservasGDS r
			INNER JOIN dbo.fnSplitMejorado(@id_reservas,',',0,1) AS s ON CONVERT(INT,s.Codigo) = r.id

			SELECT 
				r.id, --0
				r.id_reserva, --1
				ISNULL(r.id_reservaGDS_detalles,0) AS id_reservaGDS_detalles, --2
				ISNULL(r.id_reservaGDS_servicios,0) AS id_reservaGDS_servicios, --3
				r.in_orden, --4
				fp.id AS id_formaspago, --5
				r.cd_codigo, --6
				r.ds_nombre, --7
				ISNULL(tc.id,0) AS id_tarjetascredito, --8
				ISNULL(r.cd_tipotarjeta,'') AS cd_tipotarjeta, --9
				ISNULL(r.ds_numerotarjeta,'') AS ds_numerotarjeta, --10
				ISNULL(r.ds_vouchertarjeta,'') AS ds_vouchertarjeta, --11
				ISNULL(r.ds_expiraciontarjeta,'') AS ds_expiraciontarjeta, --12
				ISNULL(r.ds_autorizaciontarjeta,'') AS ds_autorizaciontarjeta, --13
				ISNULL(r.in_coutas,0) AS in_coutas, --14
				ISNULL(r.cd_banco,'') AS cd_banco, --15
				ISNULL(r.ds_cheque,'') AS ds_cheque, --16
				ISNULL(r.ds_plaza,'') AS ds_plaza, --17
				ISNULL(r.ds_referencia,'') AS ds_referencia, --18
				ISNULL(r.ds_Poliza,'') AS ds_Poliza, --19
				ISNULL(r.ds_PolizaAnexo,'') AS ds_PolizaAnexo, --20
				r.am_valor --21
			FROM dbo.ReservaGDS_FormasPagos r
			INNER JOIN @Tabla t ON t.id_Reserva = r.id_reserva
			INNER JOIN dbo.FormasPago fp ON fp.cd_codigo = r.cd_codigo
			LEFT JOIN dbo.TarjetasCredito tc ON tc.cd_codigo = r.cd_tipotarjeta
			ORDER BY r.id_reservaGDS_detalles,r.id_reservaGDS_servicios,r.in_orden
			
END


GO

IF OBJECT_ID('dbo.spza_ReservasGDSJOB_Itinerario', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spza_ReservasGDSJOB_Itinerario;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE [dbo].[spza_ReservasGDSJOB_Itinerario] 

	@id_reserva 	Varchar(8000)

 
AS
BEGIN
Set NoCount On

			SELECT 
				id, 
				id_reserva, 
				orden, 
				cd_origen, 
				cd_destino, 
				IsNull(cd_clase,'') As cd_clase, 
				ISNULL(CONVERT(VARCHAR(10),fecha_salida,111),'') AS fecha_salida,
				IsNull(hora_salida,'') As hora_salida, 
				IsNull(hora_llegada,'') As hora_llegada, 
				IsNull(terminal,'') As terminal, 
				IsNull(cd_aero_siglas,'') As cd_aero_siglas,
				IsNull(cd_farebasis,'') As cd_farebasis,
				IsNull(ds_NumVuelo,'') As ds_NumVuelo, /*rgelis 2014/01/31 req.17473*/
				IsNull(ds_TipoVuelo,'') As ds_TipoVuelo, /*rgelis 2014/01/31 req.17473*/
				IsNull(am_valor,0) As am_valor,
				IsNull(0,0) As bl_NoUtilizado,
				IsNull(am_co2,0) As am_co2
			FROM dbo.ReservaGDS_Itinerarios I
			INNER JOIN dbo.fnSplit(@Id_Reserva,',',0,1) AS R ON R.Codigo=I.id_reserva
			--where id_reserva = @id_reserva
			ORDER BY Orden

END


GO

IF OBJECT_ID('dbo.spJOBFacturacionAuto', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spJOBFacturacionAuto;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE Procedure spJOBFacturacionAuto
	 
	As
Begin
	Set NoCount On

	Declare @Tiempo varchar(20)
	Declare @Horas varchar(20)
	Declare @Minutos varchar(20)
	Declare @Segundos varchar(20)
	Declare @TiempoN Int
	Declare @TiempoNAux Float
	Declare @Error Int
	

	Declare @Iden Int
	Declare @Categoria varchar(50)
	Declare @Operacion varchar(500)
	Declare @Llave1 varchar(50)
	Declare @Llave2 varchar(50)
	Declare @Llave3 varchar(50)
	Declare @Llave4 varchar(50)
	Declare @transaccion_guid uniqueidentifier
	Declare @Estado varchar(50)
	Declare @UltimoMensaje varchar(1000)
	Declare @Procesado datetime
	Declare @id_facture INT

	Declare @Fecha datetime
	Declare @FechaCont datetime
	Declare @Intentos Int
	Declare @Minute_wait INT

	Declare @MsjErrorValidar Varchar(MAX)
	Declare @Mensaje_Error Varchar(500);

	Declare @cur_cd_sucursal VARCHAR(MAX)
	Declare @cur_cd_implante VARCHAR(MAX)
	Declare @cur_id_sucursal INT
	Declare @cur_id_implante INT

	Declare @ReservaFactura VARCHAR(100)
	Declare @ds_cliid CHAR(10)
	Declare @cd_cliente CHAR(10)
	Declare @ds_cliname VARCHAR(250)
	Declare @ds_clidir VARCHAR(250)
	Declare @ds_clicity VARCHAR(50)
	Declare @ds_clitel VARCHAR(25)
	Declare @ds_ClienteEmail VARCHAR(100)
	Declare @ds_moneda CHAR(3)
	Declare @cd_vendedor CHAR(3)
	Declare @cd_tiqueteador VARCHAR(6)
	Declare @am_TasaCambio MONEY
	Declare @cd_tipoventa VARCHAR(10)
	Declare @cd_licitacion INT
	Declare @ds_descripcion VARCHAR(500)
	Declare @ds_Observaciones VARCHAR(8000)
	Declare @ds_archivo VARCHAR(250)
	Declare @id_reserva INT
	Declare @cd_reserva VARCHAR(10)
	Declare @cd_sucursal CHAR(5)
	Declare @cd_implante CHAR(5)
	Declare @id_sucursal INT
	Declare @id_implante INT
	Declare @cd_bu VARCHAR(25) 

	Declare @id_monedas_iata INT
	Declare @id_tiqueteador INT
	Declare @id_tipoventa INT
	Declare @am_tcambiousd MONEY
	Declare @ValorFactura MONEY

	Declare @ds_impas_iva VARCHAR(50)
	Declare @cd_impcta_iva VARCHAR(16)
	Declare @am_porcentaje_iva NUMERIC(5,2)

	-- Variables to fetch item fields inside the cursor of a specific invoice
	Declare @item_Tipo VARCHAR(5)
	Declare @item_id_reserva INT
	Declare @item_iden_gds INT
	Declare @item_ds_aero_code CHAR(3)
	Declare @item_ds_tkt_number CHAR(10)
	Declare @item_in_nacionalidad TINYINT
	Declare @item_am_tarifa MONEY
	Declare @item_am_iva MONEY
	Declare @item_am_tua MONEY
	Declare @item_am_comb MONEY
	Declare @item_am_vat MONEY
	Declare @item_am_Comision MONEY
	Declare @item_ds_pax_firstnm VARCHAR(30)
	Declare @item_ds_pax_lastnm VARCHAR(30)
	Declare @item_ds_pax_prefix CHAR(3)
	Declare @item_cd_tourcode VARCHAR(25)
	Declare @item_NumTktConj INT
	Declare @item_cd_TipoTiquete CHAR(3)
	Declare @item_id_air INT
	Declare @item_ds_itinerario VARCHAR(250)
	Declare @item_cd_Ahorro CHAR(3)
	Declare @item_am_highfare MONEY
	Declare @item_am_lowfare MONEY
	Declare @item_ds_solicita VARCHAR(200)
	Declare @item_ds_lapsoviaje VARCHAR(50)
	Declare @item_cd_tktrevisado VARCHAR(14)
	Declare @item_cd_PasaportePax VARCHAR(25)
	Declare @item_am_PorFacParcial MONEY
	Declare @item_in_cantpax INT
	Declare @item_Id_Precompra INT
	Declare @item_cd_FormaPagoTAO VARCHAR(3)
	Declare @item_TarjetaCreditoTAO VARCHAR(4)
	Declare @item_NumeroTarjetaTAO VARCHAR(25)
	Declare @item_am_fptao MONEY
	Declare @item_am_tao MONEY
	Declare @item_am_ivatao MONEY
	Declare @item_Id_Srv INT
	Declare @item_cd_conceptofacturacion INT
	Declare @item_cd_tiposervicio INT
	Declare @item_cd_proveedores VARCHAR(25)
	Declare @item_ds_proveedores VARCHAR(250)
	Declare @item_cd_confirmation VARCHAR(25)
	Declare @item_dt_checkin SMALLDATETIME
	Declare @item_dt_checkout SMALLDATETIME
	Declare @item_cd_city VARCHAR(25)
	Declare @item_in_noches INT
	Declare @item_Servicio VARCHAR(123)
	Declare @item_Descrip VARCHAR(78)
	Declare @item_am_TarifaContado MONEY
	Declare @item_am_IvaContado MONEY
	Declare @item_am_TarifaCredito MONEY
	Declare @item_am_IvaCredito MONEY
	Declare @item_cd_centrocosto VARCHAR(50)
	Declare @item_cd_auxiliar VARCHAR(50)
	DECLARE @item_cd_item VARCHAR(50)
	Declare @item_cd_fp_OtrosItems VARCHAR(3)
	Declare @item_id_tipoproveedor INT
	Declare @item_cd_tipoproveedor VARCHAR(10)
	Declare @item_ds_tipoproveedor VARCHAR(100)
	Declare @item_Fecha_Salida SMALLDATETIME
	Declare @item_Fecha_Llegada SMALLDATETIME
	Declare @item_PNR VARCHAR(62)
	Declare @item_ds_itinerarioaerolinea VARCHAR(128)
	Declare @item_ds_tkt_prefix CHAR(3)
	Declare @item_bl_ahorro BIT
	Declare @item_cd_VencimientoTarjetaTAO CHAR(6)
	Declare @item_cd_NumeroPolizaTAO VARCHAR(50)
	Declare @item_cd_AnexoPolizaTAO VARCHAR(50)
	Declare @item_ds_AutorizacionTarjetaTAO VARCHAR(25)
	Declare @item_in_cuotasTarjetaTAO INT
	Declare @item_id_FormasPago INT
	Declare @item_id_TarjetasCredito INT
	Declare @item_am_fp1 MONEY
	Declare @item_ds_cc_code VARCHAR(2)
	Declare @item_ds_cc_number VARCHAR(25)
	Declare @item_ds_cc_vence VARCHAR(5)
	Declare @item_ds_cc_autorizacion VARCHAR(25)
	Declare @item_ds_cc_voucher VARCHAR(25)
	Declare @item_in_cc_cuotas INT
	Declare @item_am_fp2 MONEY
	Declare @item_ds_cc_code2 VARCHAR(2)
	Declare @item_ds_cc_number2 VARCHAR(25)
	Declare @item_ds_cc_vence2 VARCHAR(5)
	Declare @item_ds_cc_autorizacion2 VARCHAR(25)
	Declare @item_ds_cc_voucher2 VARCHAR(25)
	Declare @item_in_cc_cuotas2 INT
	Declare @item_cd_pax_CC VARCHAR(20)
	Declare @item_cd_destino VARCHAR(3)
	Declare @item_ds_clases VARCHAR(61)
	Declare @item_ds_Observaciones VARCHAR(8000)
	Declare @item_ds_fecha SMALLDATETIME
	Declare @SqlStmt NVARCHAR(MAX)

	Declare @ItemIndex INT
	Declare @ContadoRatio FLOAT
	Declare @TarifaSqlStmt NVARCHAR(MAX)
	Declare @TktSqlStmt NVARCHAR(MAX)
	Declare @TktItinSqlStmt NVARCHAR(MAX)
	Declare @TaoCargSqlStmt NVARCHAR(MAX)
	Declare @TaoFpSqlStmt NVARCHAR(MAX)
	Declare @TaoSqlStmt NVARCHAR(MAX)
	Declare @SrvCargSqlStmt NVARCHAR(MAX)
	Declare @SrvProvSqlStmt NVARCHAR(MAX)
	Declare @SrvPaxSqlStmt NVARCHAR(MAX)
	Declare @SrvHtlSqlStmt NVARCHAR(MAX)
	Declare @SrvImpuestosSqlStmt NVARCHAR(MAX)
	Declare @SrvFpSqlStmt NVARCHAR(MAX)
	Declare @SrvSqlStmt NVARCHAR(MAX)

	Declare @id_formaspago_tao INT
	Declare @ds_fpnm_tao VARCHAR(50)
	Declare @id_tarjetascredito_tao INT

	Declare @ResultTable TABLE (
		Respuesta VARCHAR(1000), 
		Estado INT,
		id_ReciboCaja INT,
		id_FormaPago INT,
		ds_FormaPago VARCHAR(100),
		cd_fuente VARCHAR(10),
		cd_serie VARCHAR(10),
		cd_consecutivo VARCHAR(20),
		ds_Tipo VARCHAR(50),
		am_valor MONEY,
		Resolucionmsg VARCHAR(1000),
		NCF VARCHAR(50),
		FechaCaducidad DATETIME,
		ds_Alerta VARCHAR(1000),
		in_ConsecutivoUnicoDocumento INT,
		DocumentoCausacionCxP VARCHAR(100)
	)
	Declare @FacturaRespuesta VARCHAR(MAX)
	Declare @FacturaEstado INT

	-- Variables for #GenerarConceptosAuto cursor loop
	Declare @c_id_ConceptoFacturacion INT
	Declare @c_cd_ConceptoFacturacion VARCHAR(50)
	Declare @c_ds_ConceptoFacturacion VARCHAR(250)
	Declare @c_id_TiposConceptFac INT
	Declare @c_bl_contorlarCargImp BIT
	Declare @c_bl_CalculoAutoValoresFacturacion BIT
	Declare @c_id_TiposServicio INT
	Declare @c_cd_TiposServicio VARCHAR(50)
	Declare @c_ds_TiposServicio VARCHAR(250)
	Declare @c_cd_proveedores VARCHAR(25)
	Declare @c_ds_proveedores VARCHAR(250)
	Declare @c_cd_tiquete VARCHAR(50)
	Declare @c_ds_servicio VARCHAR(250)
	Declare @c_ds_descrip VARCHAR(500)
	Declare @c_ds_paxname VARCHAR(30)
	Declare @c_ds_paxape VARCHAR(30)
	Declare @c_cd_paxtype CHAR(3)
	Declare @c_ds_paxClasificacion CHAR(6)
	Declare @c_in_nacionalidad TINYINT
	Declare @c_dt_llegada SMALLDATETIME
	Declare @c_dt_salida SMALLDATETIME
	Declare @c_cd_cencosto VARCHAR(50)
	Declare @c_cd_auxiliar VARCHAR(50)
	Declare @c_cd_item VARCHAR(50)
	Declare @c_Valor MONEY
	Declare @c_am_Contado MONEY
	Declare @c_am_Credito MONEY
	Declare @c_ValorIva MONEY
	Declare @c_Total MONEY
	Declare @c_PorIva NUMERIC(5,2)
	Declare @c_am_ContadoIva MONEY
	Declare @c_am_CreditoIva MONEY
	Declare @c_codigoimpiva VARCHAR(3)
	Declare @c_nombreimpiva VARCHAR(50) 
	Declare @c_ColId VARCHAR(25)
	Declare @c_cd_Consecutivo_depende VARCHAR(50)
	Declare @c_CodigoReserva VARCHAR(50)
	Declare @c_am_ImpuestoComision MONEY
	Declare @c_Respuesta VARCHAR(1000)
	Declare @c_bl_RutaExentaIva BIT
	Declare @c_id_FormasPago INT
	Declare @c_id_TarjetasCredito INT
	Declare @c_am_basedescuento MONEY
	Declare @c_am_pordescuento NUMERIC(8,4)
	Declare @c_id_FormasPagoAirPlus INT
	Declare @c_cd_FormasPagoAirPlus VARCHAR(3)
	Declare @c_ds_FormasPagoAirPlus VARCHAR(100)
	Declare @c_id_TarjetasCreditoAirPlus INT
	Declare @c_cd_TarjetasCreditoAirPlus VARCHAR(4)
	Declare @c_ds_numerotarjetaAirPlus VARCHAR(25)
	Declare @c_cd_codigotc VARCHAR(2)
	Declare @c_ds_numerotc VARCHAR(25)
	Declare @c_ds_vencetc VARCHAR(5)
	Declare @c_ds_autorizaciontc VARCHAR(25)
	Declare @c_ds_vouchertc VARCHAR(25)
	Declare @c_in_cuotastc INT


	DECLARE @CalcularAutoValoresItemFac CHAR(1) = 'N';
	DECLARE @RecalcTotalValue MONEY;
	DECLARE @RecalcTotalPayment MONEY;
	DECLARE @NumDecimales INT

	-- Habilitar envÃƒÂ­o de facturaciÃƒÂ³n automatica
	If Not Exists(Select * From Parametros Where Id=900 And Valor= 'S')
	Begin
		WaitFor Delay '23:59:00'
		Return
	End

	-- Fetch tax details for standard IVA (id=1)
	SELECT TOP 1 
		@ds_impas_iva = ds_nombre, 
		@cd_impcta_iva = cd_cuenta, 
		@am_porcentaje_iva = am_porcentaje,
		@c_PorIva = am_porcentaje,
		@c_codigoimpiva = cd_codigo,
		@c_nombreimpiva = ds_nombre
	FROM dbo.ImpRet 
	WHERE id = 1;

	SELECT @NumDecimales = CONVERT(INT,LTRIM(RTRIM(valor))) from dbo.parametros where id = 33;
	IF @NumDecimales IS NULL SET @NumDecimales = 2;

	SELECT @CalcularAutoValoresItemFac = ISNULL(LTRIM(RTRIM(valor)), 'N') FROM dbo.Parametros WHERE id = 326;

	
	
	-- Tiempo de espera
	Select @Tiempo = CONVERT(INT,LTRIM(RTRIM(valor))) From Parametros Where Id=901
	If IsNumeric(@Tiempo) = 1
	Begin
		Set @TiempoNAux = @Tiempo
		Set @TiempoNAux = Round(@TiempoNAux, 0)
		If @TiempoNAux > 86399 Set @TiempoNAux = 86399
		Set @TiempoN = @TiempoNAux
	End
	Else
	Begin
		Set @TiempoN = 5 
	End

	Set @Segundos = cast(@TiempoN % 60 As varchar(20))
	Set @TiempoN = @TiempoN / 60
	Set @Minutos = cast(@TiempoN % 60 As varchar(20))
	Set @TiempoN = @TiempoN / 60
	Set @Horas = cast(@TiempoN % 24 As varchar(20))
	Set @Tiempo = @Horas + ':' + @Minutos + ':' + @Segundos

	-- Create the temp table to store the query result of spza_GDSFacturacionAuto_Consultar
	CREATE TABLE #GDSFacturacionAuto (
		PNR VARCHAR(62) COLLATE DATABASE_DEFAULT,
		Tipo VARCHAR(4) COLLATE DATABASE_DEFAULT,
		Servicio VARCHAR(123) COLLATE DATABASE_DEFAULT,
		Descrip VARCHAR(78) COLLATE DATABASE_DEFAULT,
		id INT,
		iden_gds INT,
		ds_fecha SMALLDATETIME,
		cd_tiqueteador VARCHAR(6) COLLATE DATABASE_DEFAULT,
		cd_vendedor CHAR(3) COLLATE DATABASE_DEFAULT,
		cd_cliente CHAR(10) COLLATE DATABASE_DEFAULT,
		am_highfare MONEY,
		am_lowfare MONEY,
		am_fare MONEY,
		ds_reasoncode CHAR(2) COLLATE DATABASE_DEFAULT,
		ds_cliname VARCHAR(250) COLLATE DATABASE_DEFAULT,
		ds_clidir VARCHAR(250) COLLATE DATABASE_DEFAULT,
		ds_clicity VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_cliid CHAR(10) COLLATE DATABASE_DEFAULT,
		ds_itinerario VARCHAR(250) COLLATE DATABASE_DEFAULT,
		ds_clases VARCHAR(61) COLLATE DATABASE_DEFAULT,
		in_nacionalidad TINYINT,
		id_air INT,
		ds_pax_number TINYINT,
		ds_pax_firstnm VARCHAR(30) COLLATE DATABASE_DEFAULT,
		ds_pax_lastnm VARCHAR(30) COLLATE DATABASE_DEFAULT,
		ds_pax_prefix CHAR(3) COLLATE DATABASE_DEFAULT,
		ds_tkt_number CHAR(10) COLLATE DATABASE_DEFAULT,
		ds_tkt_prefix CHAR(3) COLLATE DATABASE_DEFAULT,
		ds_aero_code CHAR(3) COLLATE DATABASE_DEFAULT,
		ds_moneda CHAR(3) COLLATE DATABASE_DEFAULT,
		am_tarifa MONEY,
		am_iva MONEY,
		am_tua MONEY,
		am_comb MONEY,
		am_vat MONEY,
		ds_cc_code CHAR(2) COLLATE DATABASE_DEFAULT,
		ds_cc_number VARCHAR(25) COLLATE DATABASE_DEFAULT,
		am_tao MONEY,
		am_ivatao MONEY,
		am_cap MONEY,
		am_ivacap MONEY,
		ds_cc_code2 CHAR(2) COLLATE DATABASE_DEFAULT,
		ds_cc_number2 CHAR(16) COLLATE DATABASE_DEFAULT,
		am_fp1 MONEY,
		am_fp2 MONEY,
		cd_tktrevisado VARCHAR(14) COLLATE DATABASE_DEFAULT,
		am_TarifaContado MONEY,
		am_IvaContado MONEY,
		am_OtrosContado MONEY,
		am_TarifaCredito MONEY,
		am_IvaCredito MONEY,
		am_OtrosCredito MONEY,
		am_Comision MONEY,
		cd_clitipodoc VARCHAR(100) COLLATE DATABASE_DEFAULT,
		cd_clitipotercero CHAR(1) COLLATE DATABASE_DEFAULT,
		ds_clirazoncial VARCHAR(250) COLLATE DATABASE_DEFAULT,
		ds_cliname2 VARCHAR(60) COLLATE DATABASE_DEFAULT,
		ds_clilastname VARCHAR(60) COLLATE DATABASE_DEFAULT,
		ds_clilastname2 VARCHAR(60) COLLATE DATABASE_DEFAULT,
		cd_clipais VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_clitel VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_TipoTransaccion VARCHAR(1) COLLATE DATABASE_DEFAULT,
		Fecha_Salida SMALLDATETIME,
		Fecha_Llegada SMALLDATETIME,
		Id_Srv INT,
		cd_conceptofacturacion INT,
		cd_tiposervicio INT,
		cd_proveedores VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_proveedores VARCHAR(250) COLLATE DATABASE_DEFAULT,
		id_car INT,
		dt_entrega SMALLDATETIME,
		in_cars INT,
		cd_carcode VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_conf_car VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_citysalida VARCHAR(25) COLLATE DATABASE_DEFAULT,
		dt_retorno SMALLDATETIME,
		cd_cartype VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_currency VARCHAR(10) COLLATE DATABASE_DEFAULT,
		am_tarifacar MONEY,
		cd_bookingsource VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_ratecode VARCHAR(25) COLLATE DATABASE_DEFAULT,
		id_htl INT,
		dt_checkin SMALLDATETIME,
		in_guests INT,
		cd_confirmation VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_city VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_htlchain VARCHAR(25) COLLATE DATABASE_DEFAULT,
		dt_checkout SMALLDATETIME,
		in_noches INT,
		ds_htlname VARCHAR(250) COLLATE DATABASE_DEFAULT,
		in_habs INT,
		cd_bed VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_ratecode_htl VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_htlcur VARCHAR(10) COLLATE DATABASE_DEFAULT,
		am_htltarifa MONEY,
		cd_agcur VARCHAR(10) COLLATE DATABASE_DEFAULT,
		am_agtarifa MONEY,
		ds_dir1 VARCHAR(250) COLLATE DATABASE_DEFAULT,
		ds_tel VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_fax VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_centrocosto VARCHAR(50) COLLATE DATABASE_DEFAULT,
		NumTktConj INT,
		Respuesta VARCHAR(1) COLLATE DATABASE_DEFAULT,
		ds_solicita VARCHAR(200) COLLATE DATABASE_DEFAULT,
		cd_pax_CC VARCHAR(20) COLLATE DATABASE_DEFAULT,
		ds_lapsoviaje VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_archivo VARCHAR(250) COLLATE DATABASE_DEFAULT,
		ds_Observaciones VARCHAR(8000) COLLATE DATABASE_DEFAULT,
		ds_ClienteEmail VARCHAR(100) COLLATE DATABASE_DEFAULT,
		cd_sucursal CHAR(5) COLLATE DATABASE_DEFAULT,
		cd_implante CHAR(5) COLLATE DATABASE_DEFAULT,
		bl_ClienteActualizar BIT,
		bl_NotificacionMPD BIT,
		cd_FormaPagoTAO VARCHAR(3) COLLATE DATABASE_DEFAULT,
		cd_TarjetaCreditoTAO VARCHAR(4) COLLATE DATABASE_DEFAULT,
		cd_NumeroTarjetaTAO VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_VencimientoTarjetaTAO CHAR(6) COLLATE DATABASE_DEFAULT,
		cd_NumeroPolizaTAO VARCHAR(50) COLLATE DATABASE_DEFAULT,
		cd_AnexoPolizaTAO VARCHAR(50) COLLATE DATABASE_DEFAULT,
		am_PorDesFormaPagoTA NUMERIC(8,4),
		cd_Penalidad CHAR(14) COLLATE DATABASE_DEFAULT,
		ds_cc_vence CHAR(5) COLLATE DATABASE_DEFAULT,
		ds_cc_vence2 CHAR(5) COLLATE DATABASE_DEFAULT,
		ds_cc_autorizacion VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_cc_autorizacion2 VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_cc_voucher VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_cc_voucher2 VARCHAR(10) COLLATE DATABASE_DEFAULT,
		ds_AutorizacionTarjetaTAO VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_VoucherTarjetaTAO VARCHAR(25) COLLATE DATABASE_DEFAULT,
		am_fptao MONEY,
		in_cc_cuotas INT,
		in_cc_cuotas2 INT,
		in_cuotasTarjetaTAO INT,
		cd_TipoTarifaTAO VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_TipoTiquete CHAR(3) COLLATE DATABASE_DEFAULT,
		am_TasaCambio MONEY,
		cd_tiqueteador_facturador CHAR(3) COLLATE DATABASE_DEFAULT,
		bl_ahorro BIT,
		in_CantidadTarifaTAO INT,
		in_CantidadSegmentoTAO INT,
		cd_tourcode VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_contrato VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_PasaportePax VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_itinerarioaerolinea VARCHAR(128) COLLATE DATABASE_DEFAULT,
		ds_tkt_prefixIata CHAR(3) COLLATE DATABASE_DEFAULT,
		ds_Evento VARCHAR(250) COLLATE DATABASE_DEFAULT,
		cd_iata VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_aero_codeIata CHAR(3) COLLATE DATABASE_DEFAULT,
		ReservaFactura VARCHAR(100) COLLATE DATABASE_DEFAULT,
		cd_Ahorro CHAR(3) COLLATE DATABASE_DEFAULT,
		cd_Categoria VARCHAR(50) COLLATE DATABASE_DEFAULT,
		Id_FormasPagoAirPlus INT,
		cd_FormasPagoAirPlus VARCHAR(3) COLLATE DATABASE_DEFAULT,
		ds_FormasPagoAirPlus VARCHAR(100) COLLATE DATABASE_DEFAULT,
		cd_TarjetasCreditoAirPlus VARCHAR(4) COLLATE DATABASE_DEFAULT,
		ds_numerotarjetaAirPlus VARCHAR(25) COLLATE DATABASE_DEFAULT,
		am_PorFacParcial MONEY,
		am_PorFacParcial_Utilizar MONEY,
		in_cantpax INT,
		Id_Precompra INT,
		id_sucursal INT,
		bl_cotizacion BIT,
		cd_htl VARCHAR(50) COLLATE DATABASE_DEFAULT,
		id_FormasPago INT,
		id_TarjetasCredito INT,
		id_formapago_cliente INT,
		cd_formapago_cliente VARCHAR(3) COLLATE DATABASE_DEFAULT,
		ds_formapago_cliente VARCHAR(100) COLLATE DATABASE_DEFAULT,
		cd_fp_OtrosItems VARCHAR(3) COLLATE DATABASE_DEFAULT,
		cd_auxiliar VARCHAR(50) COLLATE DATABASE_DEFAULT,
		cd_tipoventa VARCHAR(10) COLLATE DATABASE_DEFAULT,
		am_iva2 MONEY,
		cd_licitacion INT,
		ds_descripcion VARCHAR(500) COLLATE DATABASE_DEFAULT,
		id_tipoproveedor INT,
		cd_tipoproveedor VARCHAR(10) COLLATE DATABASE_DEFAULT,
		ds_tipoproveedor VARCHAR(100) COLLATE DATABASE_DEFAULT,
		cd_Consecutivo_variablesadicionales VARCHAR(50) COLLATE DATABASE_DEFAULT,
		cd_item VARCHAR(50) COLLATE DATABASE_DEFAULT
	);

	CREATE TABLE #CargosImpuestosJob (
		id INT, id_reserva INT, id_reservaGDS_detalles INT, id_reservaGDS_servicios INT,
		in_orden INT, cd_codigo VARCHAR(20) COLLATE DATABASE_DEFAULT, ds_nombre VARCHAR(100) COLLATE DATABASE_DEFAULT, cd_tipo CHAR(1) COLLATE DATABASE_DEFAULT, 
		cd_codigopadre VARCHAR(20) COLLATE DATABASE_DEFAULT, cd_tipopadre VARCHAR(20) COLLATE DATABASE_DEFAULT, am_porcentaje NUMERIC(8,4),
		am_contado MONEY, am_credito MONEY, am_valor MONEY
	);

	CREATE TABLE #FormasPagosJob (
		id INT, id_reserva INT, id_reservaGDS_detalles INT, id_reservaGDS_servicios INT,
		in_orden INT, id_formaspago INT, cd_codigo VARCHAR(10) COLLATE DATABASE_DEFAULT, ds_nombre VARCHAR(50) COLLATE DATABASE_DEFAULT,
		id_tarjetascredito INT, cd_tipotarjeta VARCHAR(10) COLLATE DATABASE_DEFAULT, ds_numerotarjeta VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_vouchertarjeta VARCHAR(50) COLLATE DATABASE_DEFAULT, ds_expiraciontarjeta VARCHAR(10) COLLATE DATABASE_DEFAULT, ds_autorizaciontarjeta VARCHAR(50) COLLATE DATABASE_DEFAULT,
		in_coutas INT, cd_banco VARCHAR(50) COLLATE DATABASE_DEFAULT, ds_cheque VARCHAR(50) COLLATE DATABASE_DEFAULT, ds_plaza VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_referencia VARCHAR(50) COLLATE DATABASE_DEFAULT, ds_Poliza VARCHAR(50) COLLATE DATABASE_DEFAULT, ds_PolizaAnexo VARCHAR(50) COLLATE DATABASE_DEFAULT, am_valor MONEY
	);

	CREATE TABLE #GenerarConceptosAuto (
		id_ConceptoFacturacion INT,
		cd_ConceptoFacturacion VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_ConceptoFacturacion VARCHAR(250) COLLATE DATABASE_DEFAULT,
		id_TiposConceptFac INT,
		bl_contorlarCargImp BIT,
		bl_CalculoAutoValoresFacturacion BIT,
		id_TiposServicio INT,
		cd_TiposServicio VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_TiposServicio VARCHAR(250) COLLATE DATABASE_DEFAULT,
		cd_proveedores VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_proveedores VARCHAR(250) COLLATE DATABASE_DEFAULT,
		cd_tiquete VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_servicio VARCHAR(250) COLLATE DATABASE_DEFAULT,
		ds_descrip VARCHAR(500) COLLATE DATABASE_DEFAULT,
		ds_paxname VARCHAR(30) COLLATE DATABASE_DEFAULT,
		ds_paxape VARCHAR(30) COLLATE DATABASE_DEFAULT,
		cd_paxtype CHAR(3) COLLATE DATABASE_DEFAULT,
		ds_paxClasificacion CHAR(6) COLLATE DATABASE_DEFAULT,
		in_nacionalidad TINYINT,
		dt_llegada SMALLDATETIME,
		dt_salida SMALLDATETIME,
		cd_cencosto VARCHAR(50) COLLATE DATABASE_DEFAULT,
		cd_auxiliar VARCHAR(50) COLLATE DATABASE_DEFAULT,
		cd_item VARCHAR(50) COLLATE DATABASE_DEFAULT,
		Valor MONEY,
		am_Contado MONEY,
		am_Credito MONEY,
		ColId VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_Consecutivo_depende VARCHAR(50) COLLATE DATABASE_DEFAULT,
		CodigoReserva VARCHAR(50) COLLATE DATABASE_DEFAULT,
		am_ImpuestoComision MONEY,
		Respuesta VARCHAR(1000) COLLATE DATABASE_DEFAULT,
		bl_RutaExentaIva BIT,
		id_FormasPago INT,
		id_TarjetasCredito INT,
		am_basedescuento MONEY,
		am_pordescuento NUMERIC(8,4),
		id_FormasPagoAirPlus INT,
		cd_FormasPagoAirPlus VARCHAR(3) COLLATE DATABASE_DEFAULT,
		ds_FormasPagoAirPlus VARCHAR(100) COLLATE DATABASE_DEFAULT,
		id_TarjetasCreditoAirPlus INT,
		cd_TarjetasCreditoAirPlus VARCHAR(4) COLLATE DATABASE_DEFAULT,
		ds_numerotarjetaAirPlus VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_codigotc VARCHAR(2) COLLATE DATABASE_DEFAULT,
		ds_numerotc VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_vencetc VARCHAR(5) COLLATE DATABASE_DEFAULT,
		ds_autorizaciontc VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_vouchertc VARCHAR(25) COLLATE DATABASE_DEFAULT,
		in_cuotastc INT
	);

	CREATE TABLE #TmpFacturaItems (
		id_item INT IDENTITY(1,1) PRIMARY KEY,
		tipo_item VARCHAR(10),                 -- 'Aire', 'TAO', 'SRV','Hotel','Auto'
		id_referencia_origen INT,              -- ID de ReservasGDS_Detalles or ReservaGDS_Servicios
		cd_tiquete VARCHAR(50),
		ds_descrip VARCHAR(500),
		in_nacionalidad INT,
		cd_cencosto VARCHAR(50),
		cd_auxiliar VARCHAR(50),
		cd_item VARCHAR(50),
		am_tarifa MONEY,
		am_iva MONEY,
		am_tua MONEY,
		am_comb MONEY,
		am_vat MONEY,
		am_Comision MONEY,
		ds_paxname VARCHAR(30),
		ds_paxape VARCHAR(30),
		ds_paxprefix CHAR(3),
		cd_tourcode VARCHAR(25),
		NumTktConj INT,
		cd_TipoTiquete CHAR(3),
		id_air INT,
		ds_itinerario VARCHAR(250),
		ds_itinerarioaerolinea VARCHAR(128),
		ds_clases VARCHAR(61),
		ds_Observaciones VARCHAR(8000),
		am_highfare MONEY,
		am_lowfare MONEY,
		ds_solicita VARCHAR(200),
		ds_lapsoviaje VARCHAR(50),
		cd_tktrevisado VARCHAR(14),
		cd_PasaportePax VARCHAR(25),
		cd_pax_CC VARCHAR(20),
		am_PorFacParcial MONEY,
		in_cantpax INT,
		Id_Precompra INT,
		cd_FormaPagoTAO VARCHAR(3),
		cd_TarjetaCreditoTAO VARCHAR(4),
		cd_NumeroTarjetaTAO VARCHAR(25),
		cd_VencimientoTarjetaTAO CHAR(6),
		cd_NumeroPolizaTAO VARCHAR(50),
		cd_AnexoPolizaTAO VARCHAR(50),
		ds_AutorizacionTarjetaTAO VARCHAR(25),
		in_cuotasTarjetaTAO INT,
		id_FormasPago INT,
		id_TarjetasCredito INT,
		am_fp1 MONEY,
		ds_cc_code VARCHAR(2),
		ds_cc_number VARCHAR(25),
		ds_cc_vence VARCHAR(5),
		ds_cc_autorizacion VARCHAR(25),
		ds_cc_voucher VARCHAR(25),
		in_cc_cuotas INT,
		am_fp2 MONEY,
		ds_cc_code2 VARCHAR(2),
		ds_cc_number2 VARCHAR(25),
		ds_cc_vence2 VARCHAR(5),
		ds_cc_autorizacion2 VARCHAR(25),
		ds_cc_voucher2 VARCHAR(25),
		in_cc_cuotas2 INT,
		id_monedas_iata INT,
		Tcambio MONEY,
		id_sucursal INT,
		id_implante INT,
		bl_ahorro BIT,
		cd_TipoTiqueteGDS VARCHAR(3),
		id_TiposDocumento INT,
		id_entdist INT,
		id_entvend INT,
		cd_destino VARCHAR(3),
		dt_fechaexped SMALLDATETIME,
		id_tiqueteadores INT,
		id_gds INT,
		iden_gds INT,
		am_comisionPNR MONEY,
		ds_records VARCHAR(62),
		bl_NoCalcComision BIT,
		bl_NoCalcIvaComision BIT,
		am_basecomisionable MONEY,
		am_porcomision MONEY,
		id_tiposconceptfac INT,
		id_conceptofacturacion INT,
		id_tiposservicio INT,
		cd_proveedores VARCHAR(25),
		ds_servicio VARCHAR(250),
		am_valorprov MONEY,
		id_monedaprov INT,
		dt_llegada SMALLDATETIME,
		dt_salida SMALLDATETIME,
		am_pordescuento NUMERIC(8,4),
		am_basedescuento MONEY,
		Fecha_Salida SMALLDATETIME,
		Fecha_Llegada SMALLDATETIME,
		ColId VARCHAR(25),
		cd_Consecutivo_depende VARCHAR(50),
		CodigoReserva VARCHAR(50),
		cd_Consecutivo_variablesadicionales VARCHAR(50),
		am_valor_total MONEY,
		ds_proveedores VARCHAR(250) COLLATE DATABASE_DEFAULT,
		id_FormasPagoAirPlus INT,
		cd_FormasPagoAirPlus VARCHAR(3) COLLATE DATABASE_DEFAULT,
		ds_FormasPagoAirPlus VARCHAR(100) COLLATE DATABASE_DEFAULT,
		id_TarjetasCreditoAirPlus INT,
		cd_TarjetasCreditoAirPlus VARCHAR(4) COLLATE DATABASE_DEFAULT,
		ds_numerotarjetaAirPlus VARCHAR(25) COLLATE DATABASE_DEFAULT,
		id_reserva INT,
		OrdenGrabacion INT
	);

	CREATE TABLE #TmpFacturaCargos (
		id_cargo_temp INT IDENTITY(1,1) PRIMARY KEY,
		id_item INT,
		cd_codigo VARCHAR(20) COLLATE DATABASE_DEFAULT,
		ds_nombre VARCHAR(100) COLLATE DATABASE_DEFAULT,
		cd_tipo CHAR(1) COLLATE DATABASE_DEFAULT,
		am_porcentaje NUMERIC(8,4),
		am_valor MONEY,
		am_contado MONEY,
		am_credito MONEY,
		id_carg INT,
		id_imp INT,
		bl_iva BIT,
		in_orden INT
	);

	CREATE TABLE #TmpFacturaFormasPago (
		id_fp_temp INT IDENTITY(1,1) PRIMARY KEY,
		id_item INT,
		id_formaspago INT,
		cd_codigo VARCHAR(10) COLLATE DATABASE_DEFAULT,
		ds_nombre VARCHAR(50) COLLATE DATABASE_DEFAULT,
		id_tarjetascredito INT,
		cd_tipotarjeta VARCHAR(10) COLLATE DATABASE_DEFAULT,
		ds_numerotarjeta VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_vouchertarjeta VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_expiraciontarjeta VARCHAR(10) COLLATE DATABASE_DEFAULT,
		ds_autorizaciontarjeta VARCHAR(50) COLLATE DATABASE_DEFAULT,
		in_cuotas INT,
		cd_banco VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_cheque VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_plaza VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_referencia VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_Poliza VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_PolizaAnexo VARCHAR(50) COLLATE DATABASE_DEFAULT,
		am_valor MONEY
	);

	While 1 = 1
	Begin
		SET @Fecha = GETDATE();
		SELECT @FechaCont=REPLACE(VALOPAR,'/','') FROM dbo.Parametr WHERE PARAMETRO = 'FECHACT'
		-- Cursor over unique combinations of sucursal/implante in queue
		--DECLARE curConfigs CURSOR LOCAL FOR
		---SELECT DISTINCT cd_sucursal, ISNULL(cd_implante, '0')
		--FROM dbo.ReservasGDS_FacAuto;

		SELECT  @cur_cd_sucursal = LTRIM(RTRIM(valor)) from dbo.parametros where id = 902;
		SELECT  @cur_cd_implante = LTRIM(RTRIM(valor)) from dbo.parametros where id = 903;

		-- Clear and fill temporary table for all configured combinations at once
		DELETE FROM #GDSFacturacionAuto;
		
		INSERT INTO #GDSFacturacionAuto
		EXEC dbo.spza_GDSFacturacionAutoJOB_Consultar 
			@id_usuario = 1, 
			@cd_sucursal = @cur_cd_sucursal, 
			@cd_implante = @cur_cd_implante;

			-- Cursor over unique ReservaFactura in this query result
			DECLARE curInvoices CURSOR LOCAL FOR
			SELECT DISTINCT ReservaFactura
			FROM #GDSFacturacionAuto;

			OPEN curInvoices;
			FETCH NEXT FROM curInvoices INTO @ReservaFactura;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				DELETE FROM #TmpFacturaItems;
				DELETE FROM #TmpFacturaCargos;
				DELETE FROM #TmpFacturaFormasPago;

				-- Fetch header details from the first record in the group

				SELECT TOP 1
					@ds_cliid = ds_cliid,
					@cd_cliente = cd_cliente,
					@ds_cliname = ds_cliname,
					@ds_clidir = ds_clidir,
					@ds_clicity = ds_clicity,
					@ds_clitel = ds_clitel,
					@ds_ClienteEmail = ds_ClienteEmail,
					@ds_moneda = ds_moneda,
					@cd_vendedor = cd_vendedor,
					@cd_tiqueteador = cd_tiqueteador,
					@am_TasaCambio = am_TasaCambio,
					@cd_tipoventa = cd_tipoventa,
					@cd_licitacion = cd_licitacion,
					@ds_descripcion = ds_descripcion,
					@ds_Observaciones = ds_Observaciones,
					@ds_archivo = ds_archivo,
					@id_reserva = id,
					@cd_reserva = PNR,
					@cd_sucursal = cd_sucursal,
					@cd_implante = cd_implante
				FROM #GDSFacturacionAuto
				WHERE ReservaFactura = @ReservaFactura;

				-- Resolve IDs for headers
				IF ISNULL(@cd_sucursal,'')=''
				BEGIN
					SET @cd_sucursal='OFP'
					SET @cd_implante=NULL
				END
				SELECT @id_sucursal = id FROM dbo.Sucursales WHERE cd_codigo = @cd_sucursal;
				SELECT @id_implante = id FROM dbo.Implantes WHERE cd_codigo = @cd_implante AND id_sucursal = @id_sucursal;
				SELECT @id_monedas_iata = id FROM dbo.Monedas_IATA WHERE cd_codigo = @ds_moneda;
				SELECT @id_tiqueteador = id FROM dbo.Tiqueteadores WHERE cd_codigo = @cd_tiqueteador;
				SELECT @id_tipoventa = id_tipoventa FROM dbo.Tiqueteadores WHERE cd_codigo = @cd_tiqueteador;
				SELECT @cd_bu = cd_bu FROM dbo.Implantes WHERE cd_codigo = @cd_implante AND id_sucursal = @id_sucursal;
				SELECT @cd_bu = cd_bu FROM dbo.Sucursales WHERE cd_codigo = @cd_sucursal AND ISNULL(@cd_bu,'')='';
				IF @id_tipoventa IS NULL SET @id_tipoventa = 1;

				SELECT TOP 1 @am_tcambiousd = am_tasa_cambio FROM dbo.Monedas_IATA WHERE cd_codigo = 'USD';
				IF @am_tcambiousd IS NULL SET @am_tcambiousd = 1.0;

				-- Calculate the total value of this invoice for verification
				SELECT @ValorFactura = SUM(
					CASE 
						WHEN Tipo = 'Aire' THEN (am_tarifa + am_iva + am_tua + am_comb + am_vat)
						ELSE am_tarifa + am_iva + am_vat
					END
				)
				FROM #GDSFacturacionAuto
				WHERE ReservaFactura = @ReservaFactura;

				UPDATE #GDSFacturacionAuto
				SET cd_Consecutivo_variablesadicionales = LEFT(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 10)
				WHERE tipo = 'SRV' AND cd_Consecutivo_variablesadicionales IS NULL

				-- Build dynamic SQL @SqlStmt
				SET @SqlStmt = '';
				SET @ItemIndex = 1;
				-- Clear and populate temporary table for concepts
				DELETE FROM #GenerarConceptosAuto;

				DECLARE @ZML_DatosXML VARCHAR(MAX);
				SET @ZML_DatosXML = 'SELECT 
										cd_cliente,
										cd_conceptofacturacion,
										cd_tiposervicio,
										in_nacionalidad,
										id_airolinea=(SELECT TOP 1 id FROM dbo.Entidades WHERE cd_siglas = ds_aero_code),
										id_moneda=(SELECT TOP 1 id FROM dbo.Monedas_IATA WHERE cd_codigo = ds_moneda),
										ds_pax_firstnm,
										ds_pax_lastnm,
										ds_pax_prefix,
										ds_paxClasificacion=NULL,
										ds_tkt_number,
										cd_proveedores,
										dt_checkin = Fecha_Salida,
										dt_checkout = Fecha_Llegada,
										cd_centrocosto,
										cd_auxiliar,
										cd_item=NULL,
										PNR,
										am_tarifa,
										am_total=CASE WHEN Tipo = ''Aire'' THEN (am_tarifa + am_iva + am_tua + am_comb + am_vat) ELSE (am_tarifa + am_iva + am_vat) END,
										Colld=CASE WHEN Tipo = ''Aire'' THEN id_air ELSE id_srv END,
										cd_Consecutivo_depende=cd_Consecutivo_variablesadicionales,
										am_Comision,
										am_ImpuestoComision=0,
										am_totalfactura=CASE WHEN Tipo = ''Aire'' THEN (am_tarifa + am_iva + am_tua + am_comb + am_vat) ELSE (am_tarifa + am_iva + am_vat) END,
										cd_tourcode,
										am_TarifaContado + am_IvaContado + am_OtrosContado,
										am_TarifaCredito + am_IvaCredito + am_OtrosCredito,
										cd_tktrevisado,
										id_TiposDocumento=(SELECT TOP 1 id FROM dbo.TiposDocumento WHERE cd_codigo = cd_TipoTiquete),
										cd_Penalidad,
										cd_TipoTiquete,
										am_TasaCambio,
										ds_itinerario,
										id_sucursal,
										id_implante=(SELECT TOP 1 id FROM dbo.Implantes WHERE cd_codigo = cd_implante),
										id_FormasPago,
										cd_TarjetaCredito=ds_cc_code,
										iden_gds,
										cd_codigotc = ds_cc_code,
										ds_numerotc = ds_cc_number,
										ds_vencetc = ds_cc_vence ,
										ds_autorizaciontc = ds_cc_autorizacion,
										ds_vouchertc = ds_cc_voucher,
										in_cuotastc = in_cc_cuotas,
										id_FormasPagoTAO = (SELECT TOP 1 id FROM dbo.FormasPago WHERE cd_codigo = cd_FormaPagoTAO),
										cd_codigotcTAO = cd_TarjetaCreditoTAO,
										ds_numerotcTAO = cd_NumeroTarjetaTAO,
										ds_vencetcTAO = cd_VencimientoTarjetaTAO ,
										ds_autorizaciontcTAO = ds_AutorizacionTarjetaTAO,
										ds_vouchertcTAO = ds_VoucherTarjetaTAO,
										in_cuotastcTAO = in_cuotasTarjetaTAO 
									FROM #GDSFacturacionAuto
									WHERE ReservaFactura = ''' + REPLACE(@ReservaFactura, '''', '''''') + ''';';

				EXEC dbo.spza_GenerarConceptosAutoJOB_Consultar
					@id_usuario = 1,
					@dt_fechaFactura = @FechaCont,
					@tasa_usd = @am_tcambiousd,
					@ZML_DatosXML = @ZML_DatosXML;

				
				DELETE FROM #CargosImpuestosJob;
				DELETE FROM #FormasPagosJob;
				
				DECLARE @id_reservas VARCHAR(8000);
				SET @id_reservas = CONVERT(VARCHAR(25),@id_reserva)+','
				
				INSERT INTO #CargosImpuestosJob EXEC dbo.spza_ReservasGDSJOB_CargosImpuestos @id_reservas = @id_reservas;
				INSERT INTO #FormasPagosJob EXEC dbo.spza_ReservasGDSJOB_FormasPagos @id_reservas = @id_reservas;
				
				-- Cursor over items in this invoice group (Only Aire / Tickets)
				DECLARE curItems CURSOR LOCAL FOR
				SELECT 
					Tipo, id, iden_gds, ds_fecha, ds_aero_code, ds_tkt_number, in_nacionalidad, am_tarifa, am_iva, am_tua, am_comb, am_vat, am_Comision,
					ds_pax_firstnm, ds_pax_lastnm, ds_pax_prefix, cd_tourcode, NumTktConj, cd_TipoTiquete, id_air, ds_itinerario, cd_Ahorro, ds_clases, ds_Observaciones,
					am_highfare, am_lowfare, ds_solicita, ds_lapsoviaje, cd_tktrevisado, cd_PasaportePax, cd_pax_CC, am_PorFacParcial, in_cantpax, Id_Precompra,
					cd_FormaPagoTAO, cd_TarjetaCreditoTAO, cd_NumeroTarjetaTAO, am_fptao, am_tao, am_ivatao, Id_Srv, cd_conceptofacturacion,
					cd_tiposervicio, cd_proveedores, ds_proveedores, cd_confirmation, dt_checkin, dt_checkout, cd_city, in_noches,
					Servicio, Descrip, am_TarifaContado, am_IvaContado, am_TarifaCredito, am_IvaCredito, cd_centrocosto, cd_auxiliar, cd_item,
					cd_fp_OtrosItems, id_tipoproveedor, cd_tipoproveedor, ds_tipoproveedor, Fecha_Salida, Fecha_Llegada, PNR,
					ds_itinerarioaerolinea, ds_tkt_prefix, bl_ahorro, cd_VencimientoTarjetaTAO, cd_NumeroPolizaTAO, cd_AnexoPolizaTAO,
					ds_AutorizacionTarjetaTAO, in_cuotasTarjetaTAO, id_FormasPago, id_TarjetasCredito,
					am_fp1, ds_cc_code, ds_cc_number, ds_cc_vence, ds_cc_autorizacion, ds_cc_voucher, in_cc_cuotas,
					am_fp2, ds_cc_code2, ds_cc_number2, ds_cc_vence2, ds_cc_autorizacion2, ds_cc_voucher2, in_cc_cuotas2
				FROM #GDSFacturacionAuto
				WHERE ReservaFactura = @ReservaFactura --AND Tipo = 'Aire';
				
				OPEN curItems;
				FETCH NEXT FROM curItems INTO 
					@item_Tipo, @item_id_reserva, @item_iden_gds, @item_ds_fecha, @item_ds_aero_code, @item_ds_tkt_number, @item_in_nacionalidad, @item_am_tarifa, @item_am_iva, @item_am_tua, @item_am_comb, @item_am_vat, @item_am_Comision,
					@item_ds_pax_firstnm, @item_ds_pax_lastnm, @item_ds_pax_prefix, @item_cd_tourcode, @item_NumTktConj, @item_cd_TipoTiquete, @item_id_air, @item_ds_itinerario, @item_cd_Ahorro, @item_ds_clases, @item_ds_Observaciones,
					@item_am_highfare, @item_am_lowfare, @item_ds_solicita, @item_ds_lapsoviaje, @item_cd_tktrevisado, @item_cd_PasaportePax, @item_cd_pax_CC, @item_am_PorFacParcial, @item_in_cantpax, @item_Id_Precompra,
					@item_cd_FormaPagoTAO, @item_TarjetaCreditoTAO, @item_NumeroTarjetaTAO, @item_am_fptao, @item_am_tao, @item_am_ivatao, @item_Id_Srv, @item_cd_conceptofacturacion,
					@item_cd_tiposervicio, @item_cd_proveedores, @item_ds_proveedores, @item_cd_confirmation, @item_dt_checkin, @item_dt_checkout, @item_cd_city, @item_in_noches,
					@item_Servicio, @item_Descrip, @item_am_TarifaContado, @item_am_IvaContado, @item_am_TarifaCredito, @item_am_IvaCredito, @item_cd_centrocosto, @item_cd_auxiliar, @item_cd_item,
					@item_cd_fp_OtrosItems, @item_id_tipoproveedor, @item_cd_tipoproveedor, @item_ds_tipoproveedor, @item_Fecha_Salida, @item_Fecha_Llegada, @item_PNR,
					@item_ds_itinerarioaerolinea, @item_ds_tkt_prefix, @item_bl_ahorro, @item_cd_VencimientoTarjetaTAO, @item_cd_NumeroPolizaTAO, @item_cd_AnexoPolizaTAO,
					@item_ds_AutorizacionTarjetaTAO, @item_in_cuotasTarjetaTAO, @item_id_FormasPago, @item_id_TarjetasCredito,
					@item_am_fp1, @item_ds_cc_code, @item_ds_cc_number, @item_ds_cc_vence, @item_ds_cc_autorizacion, @item_ds_cc_voucher, @item_in_cc_cuotas,
					@item_am_fp2, @item_ds_cc_code2, @item_ds_cc_number2, @item_ds_cc_vence2, @item_ds_cc_autorizacion2, @item_ds_cc_voucher2, @item_in_cc_cuotas2;				WHILE @@FETCH_STATUS = 0
				BEGIN
					-- Calculate Contado / Credito ratio
					SET @ContadoRatio = 0.0;
					IF @item_am_tarifa > 0
					BEGIN
						SET @ContadoRatio = CAST(@item_am_TarifaContado AS FLOAT) / CAST(@item_am_tarifa AS FLOAT);
					END
					ELSE IF @item_am_IvaContado > 0
					BEGIN
						SET @ContadoRatio = 1.0;
					END
				
					
					-- Resolve destination city from itinerary if not available
					SET @item_cd_destino = NULL;
					SELECT TOP 1 @item_cd_destino = cd_destino 
					FROM dbo.ReservaGDS_Itinerarios 
					WHERE id_reserva = @item_id_reserva 
					ORDER BY orden ASC;
					
					IF @item_cd_destino IS NULL
					BEGIN
						SET @item_cd_destino = 'XXX'; -- default fall-back if no itinerary
					END

					-- Resolving document type and entities for ticket
					DECLARE @id_TiposDocumento INT;
					SELECT @id_TiposDocumento = id FROM dbo.TiposDocumento WHERE cd_codigo = @item_cd_TipoTiquete;
					IF @id_TiposDocumento IS NULL
					BEGIN
						SELECT TOP 1 @id_TiposDocumento = ISNULL(td.id,1)
						FROM dbo.Entidades e
						LEFT JOIN dbo.TiposDocumento td ON (td.id = e.id_tiposdocumentoNac AND @item_in_nacionalidad=1) OR (td.id = e.id_tiposdocumentoInter AND @item_in_nacionalidad=2)
						WHERE e.cd_siglas = @item_ds_aero_code OR e.cd_codigo = @item_ds_aero_code;

					END
					IF @id_TiposDocumento IS NULL SET @id_TiposDocumento = 1;

					DECLARE @id_entdist INT, @id_entvend INT, @bl_nogds BIT;
					SELECT @id_entvend = id ,@bl_nogds=bl_nogds FROM dbo.Entidades WHERE cd_siglas = @item_ds_aero_code OR cd_codigo = @item_ds_aero_code;

					IF ISNULL(@bl_nogds,0) = 1
					BEGIN
						SELECT TOP 1 @id_entdist = @id_entvend;
					END
					ELSE
					BEGIN
						SELECT TOP 1 @id_entdist = id FROM dbo.Entidades WHERE cd_siglas = 'BP' OR cd_codigo = 'BSP';
					END

					-- Insert ticket item into #TmpFacturaItems
					INSERT INTO #TmpFacturaItems (
						tipo_item, id_referencia_origen, cd_tiquete, ds_descrip, in_nacionalidad, cd_cencosto, cd_auxiliar, cd_item,
						am_tarifa, am_iva, am_tua, am_comb, am_vat, am_Comision,
						ds_paxname, ds_paxape, ds_paxprefix, cd_tourcode, NumTktConj, cd_TipoTiquete, id_air,
						ds_itinerario, ds_itinerarioaerolinea, ds_clases, ds_Observaciones,
						am_highfare, am_lowfare, ds_solicita, ds_lapsoviaje, cd_tktrevisado, cd_PasaportePax, cd_pax_CC,
						am_PorFacParcial, in_cantpax, Id_Precompra, cd_FormaPagoTAO, cd_TarjetaCreditoTAO, cd_NumeroTarjetaTAO,
						cd_VencimientoTarjetaTAO, cd_NumeroPolizaTAO, cd_AnexoPolizaTAO, ds_AutorizacionTarjetaTAO, in_cuotasTarjetaTAO,
						id_FormasPago, id_TarjetasCredito, am_fp1, ds_cc_code, ds_cc_number, ds_cc_vence, ds_cc_autorizacion, ds_cc_voucher, in_cc_cuotas,
						am_fp2, ds_cc_code2, ds_cc_number2, ds_cc_vence2, ds_cc_autorizacion2, ds_cc_voucher2, in_cc_cuotas2,
						id_monedas_iata, Tcambio, id_sucursal, id_implante, bl_ahorro, cd_TipoTiqueteGDS, id_TiposDocumento, id_entdist, id_entvend,
						cd_destino, dt_fechaexped, id_tiqueteadores, id_gds, iden_gds, am_comisionPNR, ds_records, bl_NoCalcComision, bl_NoCalcIvaComision,
						am_basecomisionable, am_porcomision, OrdenGrabacion, CodigoReserva, id_tiposservicio, id_conceptofacturacion
					)
					VALUES (
						@item_Tipo, @item_id_reserva, @item_ds_tkt_number, @item_Descrip, @item_in_nacionalidad, @item_cd_centrocosto, @item_cd_auxiliar, @item_cd_item,
						@item_am_tarifa, @item_am_iva, @item_am_tua, @item_am_comb, @item_am_vat, @item_am_Comision,
						@item_ds_pax_firstnm, @item_ds_pax_lastnm, @item_ds_pax_prefix, @item_cd_tourcode, @item_NumTktConj, @item_cd_TipoTiquete, @item_id_air,
						@item_ds_itinerario, @item_ds_itinerarioaerolinea, @item_ds_clases, @item_ds_Observaciones,
						@item_am_highfare, @item_am_lowfare, @item_ds_solicita, @item_ds_lapsoviaje, @item_cd_tktrevisado, @item_cd_PasaportePax, @item_cd_pax_CC,
						@item_am_PorFacParcial, @item_in_cantpax, @item_Id_Precompra, @item_cd_FormaPagoTAO, @item_TarjetaCreditoTAO, @item_NumeroTarjetaTAO,
						@item_cd_VencimientoTarjetaTAO, @item_cd_NumeroPolizaTAO, @item_cd_AnexoPolizaTAO, @item_ds_AutorizacionTarjetaTAO, @item_in_cuotasTarjetaTAO,
						@item_id_FormasPago, @item_id_TarjetasCredito, @item_am_fp1, @item_ds_cc_code, @item_ds_cc_number, @item_ds_cc_vence, @item_ds_cc_autorizacion, @item_ds_cc_voucher, @item_in_cc_cuotas,
						@item_am_fp2, @item_ds_cc_code2, @item_ds_cc_number2, @item_ds_cc_vence2, @item_ds_cc_autorizacion2, @item_ds_cc_voucher2, @item_in_cc_cuotas2,
						@id_monedas_iata, @am_TasaCambio, @id_sucursal, @id_implante, @item_bl_ahorro, @item_cd_TipoTiquete, @id_TiposDocumento, @id_entdist, @id_entvend,
						@item_cd_destino, @item_ds_fecha, @id_tiqueteador, @item_id_air, @item_iden_gds, @item_am_Comision, @item_PNR, 0, 0,
						@item_am_tarifa, 0, @ItemIndex, @item_PNR, @item_cd_tiposervicio, @item_cd_conceptofacturacion
					);

					DECLARE @NewItemId INT = SCOPE_IDENTITY();

					
					-- Cargos e Impuestos Tiquete
					IF EXISTS (
						SELECT 1 FROM #CargosImpuestosJob 
						WHERE id_reserva = @id_reserva 
						  AND id_reservaGDS_detalles = @item_id_air OR id_reservaGDS_servicios = @item_Id_Srv
					)
					BEGIN
						-- Priority 1: Use GDS bulk cargos e impuestos
						INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
						SELECT 
							@NewItemId,
							cd_codigo,
							ds_nombre,
							CASE WHEN cd_tipo='1' THEN 'C'
								 WHEN cd_tipo='2' THEN 'D'
								 WHEN cd_tipo='3' THEN 'I'
								 WHEN cd_tipo='4' THEN 'R'
							END,
							am_porcentaje,
							am_valor,
							am_contado,
							am_credito,
							CASE 
								WHEN cd_tipo IN ('1','2') 
								THEN (SELECT TOP 1 id FROM dbo.CargosDesc WHERE cd_codigo = cd_codigo)
								ELSE ISNULL((SELECT TOP 1 Id_cargo_dep FROM dbo.ImpRet WHERE cd_codigo = cd_codigo),1)
							END,
							CASE 
								WHEN cd_tipo IN ('3','4') 
								THEN (SELECT TOP 1 id FROM dbo.ImpRet WHERE cd_codigo = cd_codigo)
								ELSE NULL
							END,
							CASE WHEN cd_tipo IN ('3') AND (cd_codigo = 'IVA' OR (SELECT TOP 1 bl_iva FROM dbo.ImpRet WHERE cd_codigo = cd_codigo) = 1) THEN 1 ELSE 0 END,
							in_orden
						FROM #CargosImpuestosJob
						WHERE id_reserva = @id_reserva 
						  AND id_reservaGDS_detalles = @item_id_air OR id_reservaGDS_servicios = @item_Id_Srv;
					END
					ELSE
					BEGIN
						-- Fallback 2: Fixed charges/taxes + client configuration
						INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
						VALUES 
							(@NewItemId, 'TAR', 'Tarifa', 'C', 0, @item_am_tarifa, @item_am_TarifaContado, @item_am_TarifaCredito, 1, 0, 0, 1);

						IF @item_am_tua >= 0 AND @item_Tipo = 'Aire'
						BEGIN
							DECLARE @id_carg_tua INT;
							SELECT @id_carg_tua = id FROM dbo.CargosDesc WHERE cd_codigo = 'TUA';
							INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
							VALUES (@NewItemId, 'TUA', 'Tasa Aeroportuaria', 'C', 0, @item_am_tua, @item_am_tua * @ContadoRatio, @item_am_tua * (1 - @ContadoRatio), @id_carg_tua, 0, 0, 2);
						END;

						IF @item_am_comb >= 0 AND @item_Tipo = 'Aire'
						BEGIN
							DECLARE @id_carg_comb INT;
							SELECT @id_carg_comb = id FROM dbo.CargosDesc WHERE cd_codigo = 'CMB';
							INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
							VALUES (@NewItemId, 'CMB', 'Combustible', 'C', 0, @item_am_comb, @item_am_comb * @ContadoRatio, @item_am_comb * (1 - @ContadoRatio), @id_carg_comb, 0, 0, 3);
							
						END;

						IF @item_am_vat >= 0
						BEGIN
							DECLARE @id_carg_otr INT;
							SELECT @id_carg_otr = id FROM dbo.CargosDesc WHERE cd_codigo = 'OTR';
							INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
							VALUES (@NewItemId, 'OTR', 'Otros', 'C', 0, @item_am_vat, @item_am_vat * @ContadoRatio, @item_am_vat * (1 - @ContadoRatio), @id_carg_otr, 0, 0, 4);
						END;

						IF @item_am_iva >= 0
						BEGIN
							INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
							VALUES (@NewItemId, 'IVA', @ds_impas_iva, 'I', @am_porcentaje_iva, @item_am_iva, @item_am_IvaContado, @item_am_IvaCredito, 1, 1, 1, 1);
						END;

						-- Query concepts from spza_CargosImpAsignadosIntegradoJOB_ConsultarConceptoFac
						IF OBJECT_ID('tempdb..#TmpConceptoExtra') IS NOT NULL DROP TABLE #TmpConceptoExtra;
						CREATE TABLE #TmpConceptoExtra (
							Codigo VARCHAR(20), Concepto VARCHAR(100), Porcentaje NUMERIC(8,4), Editable CHAR(1), Calcular VARCHAR(20),
							Contado MONEY, Credito MONEY, Valor MONEY, id_carg INT, id_imp INT, Tipo CHAR(1), Nombre VARCHAR(100),
							Cuenta VARCHAR(16), Contabilizar BIT, Respuesta VARCHAR(1000), noshow BIT, id_cargo_dep INT, id_imp_dep INT,
							C_Orden INT, I_Orden INT, bl_iva BIT, bl_iva2 BIT
						);

						INSERT INTO #TmpConceptoExtra
						EXEC dbo.spza_CargosImpAsignadosIntegradoJOB_ConsultarConceptoFac 
							@id_usuario = 1, 
							@id_ConceptFac = @item_cd_conceptofacturacion, 
							@bu = @cd_bu, 
							@Id_Cliente = @cd_cliente;
						
						--IF @CalcularAutoValoresItemFac = 'S' OR EXISTS(SELECT id FROM dbo.ConceptoFacturacion WHERE id=@item_cd_conceptofacturacion AND bl_CalculoAutoValoresFacturacion=1)
						--BEGIN
						--	UPDATE #TmpConceptoExtra
						--	SET Valor = ROUND(@item_am_tarifa * (Porcentaje / 100.0), @NumDecimales),
						--		Contado = ROUND(@item_am_TarifaContado * (Porcentaje / 100.0), @NumDecimales),
						--		Credito = ROUND(@item_am_TarifaCredito * (Porcentaje / 100.0), @NumDecimales)
						--	WHERE Calcular = 'Calcular' AND Valor=0;
						--END;

						-- Exclude fixed ones ('TAR', 'TUA', 'CMB', 'OTR') and IVA (if already has IVA)
						DELETE FROM #TmpConceptoExtra WHERE Codigo IN ('TAR', 'TUA', 'CMB', 'OTR','IVA');
						--IF EXISTS (SELECT 1 FROM #TmpFacturaCargos WHERE id_item = @NewItemId AND bl_iva = 1)
						--BEGIN
						--	DELETE FROM #TmpConceptoExtra WHERE bl_iva = 1;
						--END;

						INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
						SELECT 
							@NewItemId, Codigo, Concepto, Tipo, Porcentaje, Valor, Contado, Credito, id_carg, id_imp, bl_iva, C_Orden
						FROM #TmpConceptoExtra;

						DROP TABLE #TmpConceptoExtra;
					END;
					
					-- Formas de Pago Tiquete
					IF EXISTS (
						SELECT 1 FROM #FormasPagosJob 
						WHERE id_reserva = @id_reserva 
						  AND id_reservaGDS_detalles = @item_id_air OR id_reservaGDS_servicios = @item_Id_Srv
					)
					BEGIN
						-- Priority 1: Replace all with GDS bulk formas de pago
						INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, id_tarjetascredito, cd_tipotarjeta, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_cuotas, cd_banco, ds_cheque, ds_plaza, ds_referencia, ds_Poliza, ds_PolizaAnexo, am_valor)
						SELECT 
							@NewItemId, id_formaspago, cd_codigo, ds_nombre, id_tarjetascredito, cd_tipotarjeta, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_coutas, cd_banco, ds_cheque, ds_plaza, ds_referencia, ds_Poliza, ds_PolizaAnexo, am_valor
						FROM #FormasPagosJob
						WHERE id_reserva = @id_reserva 
						  AND id_reservaGDS_detalles = @item_id_air OR id_reservaGDS_servicios = @item_Id_Srv;
					END
					ELSE
					BEGIN
						-- Fallback 2: Read payment methods from details/variables
						IF ISNULL(@item_am_fp1, 0) > 0
						BEGIN
							IF @item_ds_cc_code IS NOT NULL AND RTRIM(LTRIM(@item_ds_cc_code)) <> ''
							BEGIN
								DECLARE @fp_id_fp1 INT, @fp_id_tc1 INT;
								SELECT @fp_id_fp1 = id FROM dbo.FormasPago WHERE cd_codigo = 'TC';
								SELECT @fp_id_tc1 = id FROM dbo.tarjetascredito WHERE cd_codigo = @item_ds_cc_code;
								
								INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, id_tarjetascredito, cd_tipotarjeta, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_cuotas, am_valor)
								VALUES (@NewItemId, @fp_id_fp1, 'TC', 'Tarjeta de Credito', @fp_id_tc1, @item_ds_cc_code, @item_ds_cc_number, @item_ds_cc_voucher, @item_ds_cc_vence, @item_ds_cc_autorizacion, ISNULL(@item_in_cc_cuotas, 1), @item_am_fp1);
							END
							ELSE
							BEGIN
								DECLARE @fp_id_fp_efe INT;
								SELECT @fp_id_fp_efe = id FROM dbo.FormasPago WHERE cd_codigo = 'EFE';
								INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, am_valor)
								VALUES (@NewItemId, @fp_id_fp_efe, 'EFE', 'Efectivo', @item_am_fp1);
							END
						END;

						IF ISNULL(@item_am_fp2, 0) > 0
						BEGIN
							IF @item_ds_cc_code2 IS NOT NULL AND RTRIM(LTRIM(@item_ds_cc_code2)) <> ''
							BEGIN
								DECLARE @fp_id_fp2 INT, @fp_id_tc2 INT;
								SELECT @fp_id_fp2 = id FROM dbo.FormasPago WHERE cd_codigo = 'TC';
								SELECT @fp_id_tc2 = id FROM dbo.tarjetascredito WHERE cd_codigo = @item_ds_cc_code2;
								
								INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, id_tarjetascredito, cd_tipotarjeta, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_cuotas, am_valor)
								VALUES (@NewItemId, @fp_id_fp2, 'TC', 'Tarjeta de credito', @fp_id_tc2, @item_ds_cc_code2, @item_ds_cc_number2, @item_ds_cc_voucher2, @item_ds_cc_vence2, @item_ds_cc_autorizacion2, ISNULL(@item_in_cc_cuotas2, 1), @item_am_fp2);
							END
							ELSE
							BEGIN
								DECLARE @fp_id_fp_efe2 INT;
								SELECT @fp_id_fp_efe2 = id FROM dbo.FormasPago WHERE cd_codigo = 'EFE';
								INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, am_valor)
								VALUES (@NewItemId, @fp_id_fp_efe2, 'EFE', 'Efectivo', @item_am_fp2);
							END
						END;

						IF ISNULL(@item_am_fp1, 0) = 0 AND ISNULL(@item_am_fp2, 0) = 0 AND ISNULL(@item_am_tarifa, 0) > 0
						BEGIN
							DECLARE @fp_id_fp_default INT;
							SELECT @fp_id_fp_default = id FROM dbo.FormasPago WHERE cd_codigo = 'EFE';
							INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, am_valor)
							VALUES (@NewItemId, @fp_id_fp_default, 'EFE', 'Efectivo', @item_am_tarifa);
						END;
						-- Recalcular valor de forma de pago si el parÃ¡metro 326 estÃ¡ activo
						IF @CalcularAutoValoresItemFac = 'S' OR EXISTS(SELECT id FROM dbo.ConceptoFacturacion WHERE id=@item_cd_conceptofacturacion AND bl_CalculoAutoValoresFacturacion=1)
						BEGIN
							SELECT @RecalcTotalValue = SUM(am_valor) FROM #TmpFacturaCargos WHERE id_item = @NewItemId;
							SELECT @RecalcTotalPayment = SUM(am_valor) FROM #TmpFacturaFormasPago WHERE id_item = @NewItemId;

							IF ISNULL(@RecalcTotalPayment, 0) <> ISNULL(@RecalcTotalValue, 0)
							BEGIN
								IF EXISTS (SELECT 1 FROM #TmpFacturaFormasPago WHERE id_item = @NewItemId)
								BEGIN
									UPDATE TOP (1) #TmpFacturaFormasPago
									SET am_valor = @RecalcTotalValue
									WHERE id_item = @NewItemId;
								END
							END;
						END;
					END;

					SET @ItemIndex = @ItemIndex + 1;
					FETCH NEXT FROM curItems INTO 
						@item_Tipo, @item_id_reserva, @item_iden_gds, @item_ds_fecha, @item_ds_aero_code, @item_ds_tkt_number, @item_in_nacionalidad, @item_am_tarifa, @item_am_iva, @item_am_tua, @item_am_comb, @item_am_vat, @item_am_Comision,
						@item_ds_pax_firstnm, @item_ds_pax_lastnm, @item_ds_pax_prefix, @item_cd_tourcode, @item_NumTktConj, @item_cd_TipoTiquete, @item_id_air, @item_ds_itinerario, @item_cd_Ahorro, @item_ds_clases, @item_ds_Observaciones,
						@item_am_highfare, @item_am_lowfare, @item_ds_solicita, @item_ds_lapsoviaje, @item_cd_tktrevisado, @item_cd_PasaportePax, @item_cd_pax_CC, @item_am_PorFacParcial, @item_in_cantpax, @item_Id_Precompra,
						@item_cd_FormaPagoTAO, @item_TarjetaCreditoTAO, @item_NumeroTarjetaTAO, @item_am_fptao, @item_am_tao, @item_am_ivatao, @item_Id_Srv, @item_cd_conceptofacturacion,
						@item_cd_tiposervicio, @item_cd_proveedores, @item_ds_proveedores, @item_cd_confirmation, @item_dt_checkin, @item_dt_checkout, @item_cd_city, @item_in_noches,
						@item_Servicio, @item_Descrip, @item_am_TarifaContado, @item_am_IvaContado, @item_am_TarifaCredito, @item_am_IvaCredito, @item_cd_centrocosto, @item_cd_auxiliar, @item_cd_item,
						@item_cd_fp_OtrosItems, @item_id_tipoproveedor, @item_cd_tipoproveedor, @item_ds_tipoproveedor, @item_Fecha_Salida, @item_Fecha_Llegada, @item_PNR,
						@item_ds_itinerarioaerolinea, @item_ds_tkt_prefix, @item_bl_ahorro, @item_cd_VencimientoTarjetaTAO, @item_cd_NumeroPolizaTAO, @item_cd_AnexoPolizaTAO,
						@item_ds_AutorizacionTarjetaTAO, @item_in_cuotasTarjetaTAO, @item_id_FormasPago, @item_id_TarjetasCredito,
						@item_am_fp1, @item_ds_cc_code, @item_ds_cc_number, @item_ds_cc_vence, @item_ds_cc_autorizacion, @item_ds_cc_voucher, @item_in_cc_cuotas,
						@item_am_fp2, @item_ds_cc_code2, @item_ds_cc_number2, @item_ds_cc_vence2, @item_ds_cc_autorizacion2, @item_ds_cc_voucher2, @item_in_cc_cuotas2;
				END;

				CLOSE curItems;
				DEALLOCATE curItems;

				-- Cursor over concepts returned by spza_GenerarConceptosAuto_Consultar
				DECLARE curConcepts CURSOR LOCAL FOR
				SELECT 
					id_ConceptoFacturacion, cd_ConceptoFacturacion, ds_ConceptoFacturacion, id_TiposConceptFac, bl_contorlarCargImp, bl_CalculoAutoValoresFacturacion, id_TiposServicio, cd_TiposServicio, ds_TiposServicio, cd_proveedores, ds_proveedores, cd_tiquete, ds_servicio, ds_descrip, ds_paxname, ds_paxape, cd_paxtype, ds_paxClasificacion, in_nacionalidad, dt_llegada, dt_salida, cd_cencosto, cd_auxiliar, cd_item, Valor, am_Contado, am_Credito, ColId, cd_Consecutivo_depende, CodigoReserva, am_ImpuestoComision, Respuesta, bl_RutaExentaIva, id_FormasPago, id_TarjetasCredito, am_basedescuento, am_pordescuento, id_FormasPagoAirPlus, cd_FormasPagoAirPlus, ds_FormasPagoAirPlus, id_TarjetasCreditoAirPlus, cd_TarjetasCreditoAirPlus, ds_numerotarjetaAirPlus, cd_codigotc, ds_numerotc, ds_vencetc, ds_autorizaciontc, ds_vouchertc, in_cuotastc 
				FROM #GenerarConceptosAuto;

				OPEN curConcepts;
				FETCH NEXT FROM curConcepts INTO 
					@c_id_ConceptoFacturacion, @c_cd_ConceptoFacturacion, @c_ds_ConceptoFacturacion, @c_id_TiposConceptFac, @c_bl_contorlarCargImp, @c_bl_CalculoAutoValoresFacturacion, @c_id_TiposServicio, @c_cd_TiposServicio, @c_ds_TiposServicio, @c_cd_proveedores, @c_ds_proveedores, @c_cd_tiquete, @c_ds_servicio, @c_ds_descrip, @c_ds_paxname, @c_ds_paxape, @c_cd_paxtype, @c_ds_paxClasificacion, @c_in_nacionalidad, @c_dt_llegada, @c_dt_salida, @c_cd_cencosto, @c_cd_auxiliar, @c_cd_item, @c_Valor, @c_am_Contado, @c_am_Credito, @c_ColId, @c_cd_Consecutivo_depende, @c_CodigoReserva, @c_am_ImpuestoComision, @c_Respuesta, @c_bl_RutaExentaIva, @c_id_FormasPago, @c_id_TarjetasCredito, @c_am_basedescuento, @c_am_pordescuento, @c_id_FormasPagoAirPlus, @c_cd_FormasPagoAirPlus, @c_ds_FormasPagoAirPlus, @c_id_TarjetasCreditoAirPlus, @c_cd_TarjetasCreditoAirPlus, @c_ds_numerotarjetaAirPlus, @c_cd_codigotc, @c_ds_numerotc, @c_ds_vencetc, @c_ds_autorizaciontc, @c_ds_vouchertc, @c_in_cuotastc;

				WHILE @@FETCH_STATUS = 0
				BEGIN
					DECLARE @c_tipo_item VARCHAR(10);
					SET @c_ValorIva=0;
					SET @c_PorIva = @am_porcentaje_iva;
					SET @c_Total = @c_Valor;
					SET @c_codigoimpiva = 'IVA';
					SET @c_nombreimpiva = @ds_impas_iva;
					SET @c_am_ContadoIva = 0;
					SET @c_am_CreditoIva = 0;
					IF @c_cd_ConceptoFacturacion IN ('CAN', 'CAI')
					BEGIN
						SET @c_tipo_item = 'TAO';
						SELECT @c_codigoimpiva= ISNULL(RTRIM(LTRIM(Valor)),'') from parametros where id = 331 AND @c_in_nacionalidad=2
						SELECT @c_codigoimpiva= ISNULL(RTRIM(LTRIM(Valor)),'IVA') from parametros where id = 330 AND @c_in_nacionalidad=1
						select @c_PorIva = CONVERT(NUMERIC(5,2),ISNULL(RTRIM(LTRIM(Valor)),'0')) from parametros where id = 389
						SELECT @c_PorIva = am_porcentaje FROM dbo.ImpRet WHERE cd_codigo=@c_codigoimpiva AND am_porcentaje<>0
						SELECT @c_nombreimpiva = ds_nombre FROM dbo.ImpRet WHERE cd_codigo=@c_codigoimpiva
						IF ISNULL(@c_Poriva,0)<>0
						BEGIN
							SET @c_ValorIva=ROUND((@c_Valor * (@c_Poriva/100)),@NumDecimales);
							SET @c_Total = @c_Valor + @c_ValorIva;
						END
						SET @c_am_ContadoIva = CASE WHEN ISNULL(@c_am_Contado,0)<>0 THEN @c_ValorIva ELSE 0 END
						SEt @c_am_CreditoIva = CASE WHEN ISNULL(@c_am_Credito,0)<>0 THEN @c_ValorIva ELSE 0 END
					END
					ELSE
					BEGIN
						SET @c_tipo_item = 'SRV';
					END

					DECLARE @c_id_reserva_int INT;
					SELECT TOP 1 @c_id_reserva_int = id FROM dbo.ReservasGDS WHERE cd_codigo = @c_CodigoReserva;

					INSERT INTO #TmpFacturaItems (
						tipo_item, id_referencia_origen, cd_tiquete, ds_descrip, in_nacionalidad, cd_cencosto, cd_auxiliar, cd_item, 
						am_tarifa, am_iva, am_valor_total,
						ds_paxname, ds_paxape, ds_paxprefix, cd_tourcode,
						ds_servicio, cd_proveedores, ds_proveedores,
						dt_llegada, dt_salida, am_pordescuento, am_basedescuento,
						id_FormasPago, id_TarjetasCredito, am_fp1, ds_cc_code, ds_cc_number, ds_cc_vence, ds_cc_autorizacion, ds_cc_voucher, in_cc_cuotas, 
						id_FormasPagoAirPlus, cd_FormasPagoAirPlus, ds_FormasPagoAirPlus, id_TarjetasCreditoAirPlus, cd_TarjetasCreditoAirPlus, ds_numerotarjetaAirPlus,
						id_TiposConceptFac, id_conceptofacturacion, id_tiposservicio,
						id_monedas_iata, Tcambio, CodigoReserva, ColId, id_reserva, cd_Consecutivo_depende
					)
					VALUES (
						@c_tipo_item, TRY_CAST(@c_ColId AS INT), @c_cd_tiquete, @c_ds_descrip, @c_in_nacionalidad, @c_cd_cencosto, @c_cd_auxiliar, @c_cd_item,
						@c_Valor, @c_valorIva, @c_Total,
						@c_ds_paxname, @c_ds_paxape, @c_cd_paxtype, NULL,
						@c_ds_servicio, @c_cd_proveedores, @c_ds_proveedores,
						@c_dt_llegada, @c_dt_salida, @c_am_pordescuento, @c_am_basedescuento,
						@c_id_FormasPago, @c_id_TarjetasCredito, @c_Total, @c_cd_codigotc, @c_ds_numerotc, @c_ds_vencetc, @c_ds_autorizaciontc, @c_ds_vouchertc, @c_in_cuotastc, 
						@c_id_FormasPagoAirPlus, @c_cd_FormasPagoAirPlus, @c_ds_FormasPagoAirPlus, @c_id_TarjetasCreditoAirPlus, @c_cd_TarjetasCreditoAirPlus, @c_ds_numerotarjetaAirPlus,
						@c_id_TiposConceptFac, @c_id_ConceptoFacturacion, @c_id_TiposServicio,
						@id_monedas_iata, @am_TasaCambio, @c_CodigoReserva, @c_ColId, @c_id_reserva_int, @c_cd_Consecutivo_depende
					);

					

					DECLARE @NewConceptItemId INT = SCOPE_IDENTITY();

					-- Cargos e Impuestos Concepto
					IF @c_id_reserva_int IS NOT NULL AND @c_ColId IS NOT NULL AND EXISTS (
						SELECT 1 FROM #CargosImpuestosJob 
						WHERE id_reserva = @c_id_reserva_int 
						  AND id_reservaGDS_servicios = TRY_CAST(@c_ColId AS INT)
					)
					BEGIN
						-- Priority 1: Replace all with GDS bulk data
						INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
						SELECT 
							@NewConceptItemId,
							cd_codigo,
							ds_nombre,
							CASE WHEN cd_tipo='1' THEN 'C'
								 WHEN cd_tipo='2' THEN 'D'
								 WHEN cd_tipo='3' THEN 'I'
								 WHEN cd_tipo='4' THEN 'R'
							END,
							am_porcentaje,
							am_valor,
							am_contado,
							am_credito,
							CASE 
								WHEN cd_tipo IN ('1','2') THEN
									CASE WHEN ISNUMERIC(cd_codigo) = 1 THEN CAST(cd_codigo AS INT)
										 ELSE (SELECT TOP 1 id FROM dbo.CargosDesc WHERE cd_codigo = cd_codigo)
									END
								ELSE NULL
							END,
							CASE 
								WHEN cd_tipo IN ('3','4') THEN
									CASE WHEN ISNUMERIC(cd_codigo) = 1 THEN CAST(cd_codigo AS INT)
										 ELSE (SELECT TOP 1 id FROM dbo.ImpRet WHERE cd_codigo = cd_codigo)
									END
								ELSE NULL
							END,
							CASE WHEN cd_tipo IN ('3','4') AND (cd_codigo = 'IVA' OR (SELECT TOP 1 bl_iva FROM dbo.ImpRet WHERE cd_codigo = cd_codigo) = 1) THEN 1 ELSE 0 END,
							in_orden
						FROM #CargosImpuestosJob
						WHERE id_reserva = @c_id_reserva_int 
						  AND id_reservaGDS_servicios = TRY_CAST(@c_ColId AS INT);
					END
					ELSE
					BEGIN
						-- Fallback 2: Fixed charges/taxes according to type
						IF @c_tipo_item = 'TAO'
						BEGIN 
							-- For TAO: TAR, OTR, IVA
							INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
							VALUES 
								(@NewConceptItemId, 'TAR', 'Tarifa', 'C', 0, @c_Valor, @c_am_Contado, @c_am_Credito, 1, 0, 0, 1),
								(@NewConceptItemId, 'OTR', 'Otros cargos', 'C', 0, 0, 0, 0, 4, 0, 0, 2);

							IF ISNULL(@c_ValorIva, 0) >= 0
							BEGIN
								INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
								VALUES (@NewConceptItemId, @c_codigoimpiva, @c_nombreimpiva, 'I', @c_PorIva, @c_ValorIva, @c_am_ContadoIva, @c_am_CreditoIva, 1, 1, 1, 1);
							END;
						END
						ELSE
						BEGIN
							-- For Services/Fees: TAR, IVA
							INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
							VALUES (@NewConceptItemId, 'TAR', 'Tarifa', 'C', 0, @c_Valor, @c_am_Contado, @c_am_Credito, 1, 0, 0, 1),
								   (@NewConceptItemId, 'OTR', 'Otros', 'C', 0, 0, 0, 0, 4, 0, 0, 2);

							IF ISNULL(@c_ValorIva, 0) >= 0
							BEGIN
								INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
								VALUES (@NewConceptItemId, 'IVA', @ds_impas_iva, 'I', @c_PorIva,  @c_ValorIva, @c_am_ContadoIva, @c_am_CreditoIva, 1, 1, 1, 1);
							END;
						END;

						-- Query configured concepts from spza_CargosImpAsignadosIntegradoJOB_ConsultarConceptoFac
						IF OBJECT_ID('tempdb..#TmpConceptoExtraAuto') IS NOT NULL DROP TABLE #TmpConceptoExtraAuto;
						CREATE TABLE #TmpConceptoExtraAuto (
							Codigo VARCHAR(20), Concepto VARCHAR(100), Porcentaje NUMERIC(8,4), Editable CHAR(1), Calcular VARCHAR(20),
							Contado MONEY, Credito MONEY, Valor MONEY, id_carg INT, id_imp INT, Tipo CHAR(1), Nombre VARCHAR(100),
							Cuenta VARCHAR(16), Contabilizar BIT, Respuesta VARCHAR(1000), noshow BIT, id_cargo_dep INT, id_imp_dep INT,
							C_Orden INT, I_Orden INT, bl_iva BIT, bl_iva2 BIT
						);

						INSERT INTO #TmpConceptoExtraAuto
						EXEC dbo.spza_CargosImpAsignadosIntegradoJOB_ConsultarConceptoFac 
							@id_usuario = 1, 
							@id_ConceptFac = @c_id_ConceptoFacturacion, 
							@bu = @cd_bu, 
							@Id_Cliente = @cd_cliente;

						-- Exclude fixed ones ('TAR', 'OTR') and IVA (if already has IVA)
						DELETE FROM #TmpConceptoExtraAuto WHERE Codigo IN ('TAR', 'OTR','IVA');
						--IF EXISTS (SELECT 1 FROM #TmpFacturaCargos WHERE id_item = @NewConceptItemId AND bl_iva = 1)
						--BEGIN
						--	DELETE FROM #TmpConceptoExtraAuto WHERE bl_iva = 1;
						--END;

						INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
						SELECT 
							@NewConceptItemId, Codigo, Concepto, Tipo, Porcentaje, Valor, Contado, Credito, id_carg, id_imp, bl_iva, C_Orden
						FROM #TmpConceptoExtraAuto;

						DROP TABLE #TmpConceptoExtraAuto;
					END;
								
				
					-- Formas de Pago Concepto
					IF @c_id_reserva_int IS NOT NULL AND @c_ColId IS NOT NULL AND EXISTS (
						SELECT 1 FROM #FormasPagosJob 
						WHERE id_reserva = @c_id_reserva_int 
						  AND id_reservaGDS_servicios = TRY_CAST(@c_ColId AS INT)
					)
					BEGIN
						-- Priority 1: Replace all with GDS bulk data
						INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, id_tarjetascredito, cd_tipotarjeta, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_cuotas, cd_banco, ds_cheque, ds_plaza, ds_referencia, ds_Poliza, ds_PolizaAnexo, am_valor)
						SELECT 
							@NewConceptItemId, id_formaspago, cd_codigo, ds_nombre, id_tarjetascredito, cd_tipotarjeta, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_coutas, cd_banco, ds_cheque, ds_plaza, ds_referencia, ds_Poliza, ds_PolizaAnexo, am_valor
						FROM #FormasPagosJob
						WHERE id_reserva = @c_id_reserva_int 
						  AND id_reservaGDS_servicios = TRY_CAST(@c_ColId AS INT);
					END
					ELSE
					BEGIN
						-- Fallback 2: Inherit or fallback payment methods
						IF @c_id_FormasPago IS NOT NULL AND @c_id_TarjetasCredito IS NOT NULL
						BEGIN
							INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, id_tarjetascredito, cd_tipotarjeta, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_cuotas, am_valor)
							VALUES (@NewConceptItemId, @c_id_FormasPago, 'TC', 'Tarjeta de Credito', @c_id_TarjetasCredito, @c_cd_codigotc, @c_ds_numerotc, @c_ds_vouchertc, @c_ds_vencetc, @c_ds_autorizaciontc, ISNULL(@c_in_cuotastc, 1), @c_Valor);
						END
						ELSE IF @c_id_FormasPagoAirPlus IS NOT NULL
						BEGIN
							INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, id_tarjetascredito, cd_tipotarjeta, ds_numerotarjeta, am_valor)
							VALUES (@NewConceptItemId, @c_id_FormasPagoAirPlus, @c_cd_FormasPagoAirPlus, @c_ds_FormasPagoAirPlus, @c_id_TarjetasCreditoAirPlus, @c_cd_TarjetasCreditoAirPlus, @c_ds_numerotarjetaAirPlus, @c_Valor);
						END
						ELSE
						BEGIN
							DECLARE @fp_id_efe_default INT;
							SELECT @fp_id_efe_default = id FROM dbo.FormasPago WHERE cd_codigo = 'EFE';
							INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, am_valor)
							VALUES (@NewConceptItemId, @fp_id_efe_default, 'EFE', 'Efectivo', @c_Valor);
						END;
						-- Recalcular valor de forma de pago si el parÃ¡metro 326 estÃ¡ activo
						IF @CalcularAutoValoresItemFac = 'S' OR EXISTS(SELECT id FROM dbo.ConceptoFacturacion WHERE id=@item_cd_conceptofacturacion AND bl_CalculoAutoValoresFacturacion=1)
						BEGIN
							SELECT @RecalcTotalValue = SUM(am_valor) FROM #TmpFacturaCargos WHERE id_item = @NewConceptItemId;
							SELECT @RecalcTotalPayment = SUM(am_valor) FROM #TmpFacturaFormasPago WHERE id_item = @NewConceptItemId;

							IF ISNULL(@RecalcTotalPayment, 0) <> ISNULL(@RecalcTotalValue, 0)
							BEGIN
								IF EXISTS (SELECT 1 FROM #TmpFacturaFormasPago WHERE id_item = @NewConceptItemId)
								BEGIN
									UPDATE TOP (1) #TmpFacturaFormasPago
									SET am_valor = @RecalcTotalValue
									WHERE id_item = @NewConceptItemId;
								END
							END;
						END;
					END;

					SET @ItemIndex = @ItemIndex + 1;
					FETCH NEXT FROM curConcepts INTO 
						@c_id_ConceptoFacturacion, @c_cd_ConceptoFacturacion, @c_ds_ConceptoFacturacion, @c_id_TiposConceptFac, @c_bl_contorlarCargImp, @c_bl_CalculoAutoValoresFacturacion, @c_id_TiposServicio, @c_cd_TiposServicio, @c_ds_TiposServicio, @c_cd_proveedores, @c_ds_proveedores, @c_cd_tiquete, @c_ds_servicio, @c_ds_descrip, @c_ds_paxname, @c_ds_paxape, @c_cd_paxtype, @c_ds_paxClasificacion, @c_in_nacionalidad, @c_dt_llegada, @c_dt_salida, @c_cd_cencosto, @c_cd_auxiliar, @c_cd_item, @c_Valor, @c_am_Contado, @c_am_Credito, @c_ColId, @c_cd_Consecutivo_depende, @c_CodigoReserva, @c_am_ImpuestoComision, @c_Respuesta, @c_bl_RutaExentaIva, @c_id_FormasPago, @c_id_TarjetasCredito, @c_am_basedescuento, @c_am_pordescuento, @c_id_FormasPagoAirPlus, @c_cd_FormasPagoAirPlus, @c_ds_FormasPagoAirPlus, @c_id_TarjetasCreditoAirPlus, @c_cd_TarjetasCreditoAirPlus, @c_ds_numerotarjetaAirPlus, @c_cd_codigotc, @c_ds_numerotc, @c_ds_vencetc, @c_ds_autorizaciontc, @c_ds_vouchertc, @c_in_cuotastc;
				END;

				CLOSE curConcepts;
				DEALLOCATE curConcepts;

				-- Generar cd_Consecutivo_variablesadicionales aleatorio para los servicios padres
				UPDATE #TmpFacturaItems
				SET cd_Consecutivo_variablesadicionales = LEFT(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 10)
				WHERE tipo_item IN ('SRV','Hotel','Auto') AND cd_Consecutivo_variablesadicionales IS NULL
				 
				UPDATE C
				SET C.am_valor = ROUND(p.am_valor * (C.am_porcentaje/ 100.0), @NumDecimales),
					C.am_contado = ROUND(p.am_contado * (C.am_porcentaje / 100.0), @NumDecimales),
					C.am_Credito = ROUND(p.am_Credito * (C.am_porcentaje / 100.0), @NumDecimales)
				FROM #TmpFacturaCargos C
				INNER JOIN #TmpFacturaCargos P ON P.id_cargo_temp <> C.id_cargo_temp AND P.id_item = C.id_item AND p.id_carg = C.id_carg AND ISNULL(P.am_valor,0)<>0 AND P.cd_tipo = 'C'
				INNER JOIN #TmpFacturaItems FI ON FI.id_item = C.id_item
				inner join dbo.ConceptoFacturacion CF ON CF.id = FI.id_conceptofacturacion
				WHERE ISNULL(C.am_valor,0)=0 AND ISNULL(C.am_porcentaje,0)<>0 AND C.cd_tipo IN ('I') AND (@CalcularAutoValoresItemFac = 'S' OR CF.bl_CalculoAutoValoresFacturacion=1);	

				UPDATE FP
				SET FP.am_valor=ISNULL((SELECT SUM(C.am_valor) FROM #TmpFacturaCargos C WHERE C.id_item = FP.id_item AND ISNULL(C.am_valor,0)<>0),FP.am_valor) 
				FROM #TmpFacturaFormasPago FP
				INNER JOIN #TmpFacturaItems FI ON FI.id_item = FP.id_item
				INNER JOIN dbo.ConceptoFacturacion CF ON CF.id = FI.id_conceptofacturacion
				WHERE (@CalcularAutoValoresItemFac = 'S' OR CF.bl_CalculoAutoValoresFacturacion=1);
								
				-- Reconstruct dynamic @SqlStmt from tables
				SET @SqlStmt = '';
				SET @ItemIndex = 1;

				DECLARE @gen_id_item INT, @gen_tipo_item VARCHAR(10), @gen_cd_tiquete VARCHAR(50), @gen_ds_descrip VARCHAR(500), @gen_in_nacionalidad INT, @gen_cd_cencosto VARCHAR(50), @gen_cd_auxiliar VARCHAR(50), @gen_cd_item VARCHAR(50), @gen_am_tarifa MONEY, @gen_am_iva MONEY, @gen_am_tua MONEY, @gen_am_comb MONEY, @gen_am_vat MONEY, @gen_am_Comision MONEY, @gen_ds_paxname VARCHAR(30), @gen_ds_paxape VARCHAR(30), @gen_ds_paxprefix CHAR(3), @gen_cd_tourcode VARCHAR(25), @gen_NumTktConj INT, @gen_cd_TipoTiquete CHAR(3), @gen_id_air INT, @gen_ds_itinerario VARCHAR(250), @gen_ds_itinerarioaerolinea VARCHAR(128), @gen_ds_clases VARCHAR(61), @gen_ds_Observaciones VARCHAR(8000), @gen_am_highfare MONEY, @gen_am_lowfare MONEY, @gen_ds_solicita VARCHAR(200), @gen_ds_lapsoviaje VARCHAR(50), @gen_cd_tktrevisado VARCHAR(14), @gen_cd_PasaportePax VARCHAR(25), @gen_cd_pax_CC VARCHAR(20), @gen_am_PorFacParcial MONEY, @gen_in_cantpax INT, @gen_Id_Precompra INT, @gen_id_FormasPago INT, @gen_id_TarjetasCredito INT, @gen_id_sucursal INT, @gen_id_implante INT, @gen_bl_ahorro BIT, @gen_cd_TipoTiqueteGDS VARCHAR(3), @gen_id_TiposDocumento INT, @gen_id_entdist INT, @gen_id_entvend INT, @gen_cd_destino VARCHAR(3), @gen_dt_fechaexped SMALLDATETIME, @gen_id_tiqueteadores INT, @gen_id_gds INT, @gen_iden_gds INT, @gen_am_comisionPNR MONEY, @gen_ds_records VARCHAR(62), @gen_bl_NoCalcComision BIT, @gen_bl_NoCalcIvaComision BIT, @gen_am_basecomisionable MONEY, @gen_am_porcomision MONEY, @gen_id_tiposconceptfac INT, @gen_id_conceptofacturacion INT, @gen_id_tiposservicio INT, @gen_cd_proveedores VARCHAR(25), @gen_ds_servicio VARCHAR(250), @gen_am_valorprov MONEY, @gen_id_monedaprov INT, @gen_dt_llegada SMALLDATETIME, @gen_dt_salida SMALLDATETIME, @gen_am_pordescuento NUMERIC(8,4), @gen_Fecha_Salida SMALLDATETIME, @gen_Fecha_Llegada SMALLDATETIME, @gen_am_basedescuento MONEY, @gen_cd_Consecutivo_depende VARCHAR(50), @gen_cd_Consecutivo_variablesadicionales VARCHAR(50), @gen_id_referencia_origen INT;

				DECLARE curGenItems CURSOR LOCAL FAST_FORWARD FOR
				SELECT 
					id_item, tipo_item, cd_tiquete, ds_descrip, in_nacionalidad, cd_cencosto, cd_auxiliar, cd_item, am_tarifa, am_iva, am_tua, am_comb, am_vat, am_Comision,
					ds_paxname, ds_paxape, ds_paxprefix, cd_tourcode, NumTktConj, cd_TipoTiquete, id_air, ds_itinerario, ds_itinerarioaerolinea, ds_clases, ds_Observaciones,
					am_highfare, am_lowfare, ds_solicita, ds_lapsoviaje, cd_tktrevisado, cd_PasaportePax, cd_pax_CC, am_PorFacParcial, in_cantpax, Id_Precompra,
					id_FormasPago, id_TarjetasCredito, id_sucursal, id_implante, bl_ahorro, cd_TipoTiqueteGDS, id_TiposDocumento, id_entdist, id_entvend,
					cd_destino, dt_fechaexped, id_tiqueteadores, id_gds, iden_gds, am_comisionPNR, ds_records, bl_NoCalcComision, bl_NoCalcIvaComision,
					am_basecomisionable, am_porcomision, id_tiposconceptfac, id_conceptofacturacion, id_tiposservicio, cd_proveedores, ds_servicio,
					am_valorprov, id_monedaprov, dt_llegada, dt_salida, am_pordescuento, Fecha_Salida, Fecha_Llegada, am_basedescuento, cd_Consecutivo_depende, cd_Consecutivo_variablesadicionales, id_referencia_origen
				FROM #TmpFacturaItems
				ORDER BY id_item;

				IF OBJECT_ID('tempdb..#TmpVariablesObtenidas') IS NOT NULL DROP TABLE #TmpVariablesObtenidas;
				CREATE TABLE #TmpVariablesObtenidas (
					Iden_Variable INT,
					Nombre VARCHAR(100) COLLATE DATABASE_DEFAULT,
					ValorObtenido VARCHAR(MAX) COLLATE DATABASE_DEFAULT,
					Id_Reserva INT,
					IDEN_Maestro INT,
					cd_Maestro VARCHAR(50) COLLATE DATABASE_DEFAULT
				);

				OPEN curGenItems;
				FETCH NEXT FROM curGenItems INTO 
					@gen_id_item, @gen_tipo_item, @gen_cd_tiquete, @gen_ds_descrip, @gen_in_nacionalidad, @gen_cd_cencosto, @gen_cd_auxiliar, @gen_cd_item, @gen_am_tarifa, @gen_am_iva, @gen_am_tua, @gen_am_comb, @gen_am_vat, @gen_am_Comision,
					@gen_ds_paxname, @gen_ds_paxape, @gen_ds_paxprefix, @gen_cd_tourcode, @gen_NumTktConj, @gen_cd_TipoTiquete, @gen_id_air, @gen_ds_itinerario, @gen_ds_itinerarioaerolinea, @gen_ds_clases, @gen_ds_Observaciones,
					@gen_am_highfare, @gen_am_lowfare, @gen_ds_solicita, @gen_ds_lapsoviaje, @gen_cd_tktrevisado, @gen_cd_PasaportePax, @gen_cd_pax_CC, @gen_am_PorFacParcial, @gen_in_cantpax, @gen_Id_Precompra,
					@gen_id_FormasPago, @gen_id_TarjetasCredito, @gen_id_sucursal, @gen_id_implante, @gen_bl_ahorro, @gen_cd_TipoTiqueteGDS, @gen_id_TiposDocumento, @gen_id_entdist, @gen_id_entvend,
					@gen_cd_destino, @gen_dt_fechaexped, @gen_id_tiqueteadores, @gen_id_gds, @gen_iden_gds, @gen_am_comisionPNR, @gen_ds_records, @gen_bl_NoCalcComision, @gen_bl_NoCalcIvaComision,
					@gen_am_basecomisionable, @gen_am_porcomision, @gen_id_tiposconceptfac, @gen_id_conceptofacturacion, @gen_id_tiposservicio, @gen_cd_proveedores, @gen_ds_servicio,
					@gen_am_valorprov, @gen_id_monedaprov, @gen_dt_llegada, @gen_dt_salida, @gen_am_pordescuento, @gen_Fecha_Salida, @gen_Fecha_Llegada, @gen_am_basedescuento, @gen_cd_Consecutivo_depende, @gen_cd_Consecutivo_variablesadicionales, @gen_id_referencia_origen;
			
				
				WHILE @@FETCH_STATUS = 0
				BEGIN 
					IF @gen_tipo_item IN ('Aire')
					BEGIN
						-- Build cargos / impuestos SQL
						SET @TktSqlStmt = '';
						
						DELETE FROM #TmpVariablesObtenidas;
						IF @gen_id_referencia_origen IS NOT NULL
						BEGIN
							INSERT INTO #TmpVariablesObtenidas
							EXEC dbo.spza_ConfiguracionVariablesJOB_ObtenerValores 
								@id_usuario = 1, 
								@id_ReservaGDS_Detalles = @gen_id_referencia_origen;
								
							DECLARE @var_Iden_Variable INT, @var_IDEN_Maestro INT, @var_ValorObtenido VARCHAR(MAX);
							DECLARE curVars CURSOR LOCAL FAST_FORWARD FOR
							SELECT Iden_Variable, IDEN_Maestro, ValorObtenido FROM #TmpVariablesObtenidas WHERE ISNULL(ValorObtenido, '') <> '';

							OPEN curVars;
							FETCH NEXT FROM curVars INTO @var_Iden_Variable, @var_IDEN_Maestro, @var_ValorObtenido;
							WHILE @@FETCH_STATUS = 0
							BEGIN
								SET @TktSqlStmt = @TktSqlStmt + ' INSERT INTO dbo.VariableDatosMaestro (Iden_Variable, IDEN_Maestro, cd_maestro, ValorObtenido) VALUES (' + CAST(@var_Iden_Variable AS VARCHAR) + ', ' + CAST(@var_IDEN_Maestro AS VARCHAR) + ', ''' + REPLACE(@gen_cd_tiquete, '''', '''''') + ''', ''' + REPLACE(@var_ValorObtenido, '''', '''''') + ''');' + CHAR(13) + CHAR(10)
								FETCH NEXT FROM curVars INTO @var_Iden_Variable, @var_IDEN_Maestro, @var_ValorObtenido;
							END;
							CLOSE curVars;
							DEALLOCATE curVars;
						END
						
						DECLARE @c_codigo VARCHAR(20), @ds_nombre VARCHAR(100), @cd_tipo CHAR(1), @am_porcentaje NUMERIC(8,4), @am_valor MONEY, @am_contado MONEY, @am_credito MONEY, @id_carg INT, @id_imp INT;
						
						DECLARE @TktImpuestosSqlStmt VARCHAR(MAX) = '';
						
						DECLARE curItemCargos CURSOR LOCAL FAST_FORWARD FOR
						SELECT cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp
						FROM #TmpFacturaCargos
						WHERE id_item = @gen_id_item AND cd_tipo IN ('C','D');

						OPEN curItemCargos;
						FETCH NEXT FROM curItemCargos INTO @c_codigo, @ds_nombre, @cd_tipo, @am_porcentaje, @am_valor, @am_contado, @am_credito, @id_carg, @id_imp;
						WHILE @@FETCH_STATUS = 0
						BEGIN
							DECLARE @c_codigotax VARCHAR(20), @ds_nombretax VARCHAR(100), @cd_tipotax CHAR(1), @am_porcentajetax NUMERIC(8,4), @am_valortax MONEY, @am_contadotax MONEY, @am_creditotax MONEY, @id_cargtax INT, @id_imptax INT;
							SET @TktImpuestosSqlStmt='';
							DECLARE curItemTaxes CURSOR LOCAL FAST_FORWARD FOR
							SELECT cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp
							FROM #TmpFacturaCargos
							WHERE id_item = @gen_id_item AND id_carg = @id_carg AND cd_tipo IN ('I','R');

							OPEN curItemTaxes;
							FETCH NEXT FROM curItemTaxes INTO @c_codigotax, @ds_nombretax, @cd_tipotax, @am_porcentajetax, @am_valortax, @am_contadotax, @am_creditotax, @id_cargtax, @id_imptax;
							WHILE @@FETCH_STATUS = 0
							BEGIN
								SET @TktImpuestosSqlStmt = @TktImpuestosSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_TiqueteImpuestos_Insertar @id_tiquetecargos = @NewCargId, @id_impret = ' + CAST(ISNULL(@id_imptax, 1) AS VARCHAR) + ', @ds_impas = ''' + REPLACE(@ds_nombretax, '''', '''''') + ''',@cd_impcta='''', @am_valor = ' + CAST(@am_valortax AS VARCHAR) + ', @am_contado = ' + CAST(@am_contadotax AS VARCHAR) + ', @am_credito = ' + CAST(@am_creditotax AS VARCHAR) + ', @am_porcentaje = ' + CAST(@am_porcentajetax AS VARCHAR) + ', @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @bl_contabilizar=1;'  
								FETCH NEXT FROM curItemTaxes INTO @c_codigotax, @ds_nombretax, @cd_tipotax, @am_porcentajetax, @am_valortax, @am_contadotax, @am_creditotax, @id_cargtax, @id_imptax;
							END
							CLOSE curItemTaxes;
							DEALLOCATE curItemTaxes;

							SET @TktSqlStmt = @TktSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_TiqueteCargos_Insertar @id_fac_remision = @NewRmId, @id_fac_factura = @NewFacId, @id_tiquetes = @NewTktId, @id_cargosdesc = ' + CAST(ISNULL(@id_carg, 1) AS VARCHAR) + ', @ds_cargonm = ''' + REPLACE(@ds_nombre, '''', '''''') + ''', @am_valor = ' + CAST(@am_valor AS VARCHAR) + ', @am_contado = ' + CAST(@am_contado AS VARCHAR) + ', @am_credito = ' + CAST(@am_credito AS VARCHAR) + ', @bl_noshow = 0, @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @SqlStmt = ''' + REPLACE(@TktImpuestosSqlStmt, '''', '''''') + ''';'  
							
							FETCH NEXT FROM curItemCargos INTO @c_codigo, @ds_nombre, @cd_tipo, @am_porcentaje, @am_valor, @am_contado, @am_credito, @id_carg, @id_imp;
						END
						CLOSE curItemCargos;
						DEALLOCATE curItemCargos;
								

						-- Build Formas de Pago SQL
						DECLARE @fp_id_fp INT, @fp_id_tc INT, @fp_cd_codigo VARCHAR(10), @fp_ds_nombre VARCHAR(50), @fp_cd_tipotarjeta VARCHAR(10), @fp_ds_numerotarjeta VARCHAR(50), @fp_ds_vouchertarjeta VARCHAR(50), @fp_ds_expiraciontarjeta VARCHAR(10), @fp_ds_autorizaciontarjeta VARCHAR(50), @fp_in_cuotas INT, @fp_am_valor MONEY;
						DECLARE curItemFPs CURSOR LOCAL FAST_FORWARD FOR
						SELECT id_formaspago, id_tarjetascredito, cd_codigo, ds_nombre, cd_tipotarjeta, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_cuotas, am_valor
						FROM #TmpFacturaFormasPago
						WHERE id_item = @gen_id_item;

						OPEN curItemFPs;
						FETCH NEXT FROM curItemFPs INTO @fp_id_fp, @fp_id_tc, @fp_cd_codigo, @fp_ds_nombre, @fp_cd_tipotarjeta, @fp_ds_numerotarjeta, @fp_ds_vouchertarjeta, @fp_ds_expiraciontarjeta, @fp_ds_autorizaciontarjeta, @fp_in_cuotas, @fp_am_valor;
						WHILE @@FETCH_STATUS = 0
						BEGIN
							SET @TktSqlStmt = @TktSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_TiqueteFormasPago_Insertar @id_tiquetes = @NewTktId, @id_fac_factura = @NewFacId, @id_fac_remision = @NewRmId, @id_FormasPago = ' + CAST(@fp_id_fp AS VARCHAR) + ', @ds_fpnm = ''' + REPLACE(@fp_ds_nombre, '''', '''''') + ''', @bl_fprepresenta = 0, @id_TarjetasCredito = ' + ISNULL(CAST(@fp_id_tc AS VARCHAR), 'NULL') + ', @cd_tccode = ' + ISNULL('''' + @fp_cd_tipotarjeta + '''', 'NULL') + ', @ds_tcnumber = ' + ISNULL('''' + @fp_ds_numerotarjeta + '''', 'NULL') + ', @ds_tcvoucher = ' + ISNULL('''' + @fp_ds_vouchertarjeta + '''', 'NULL') + ', @ds_tcexp = ' + ISNULL('''' + @fp_ds_expiraciontarjeta + '''', 'NULL') + ', @cd_idbanco = NULL, @ds_cheque = NULL, @ds_plaza = NULL, @ds_referencia = NULL, @ds_poliza = NULL, @ds_polanexo = NULL, @am_valor = ' + CAST(@fp_am_valor AS VARCHAR) + ', @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @ds_tcautorizacion = ' + ISNULL('''' + @fp_ds_autorizaciontarjeta + '''', 'NULL') + ', @in_tccuotas = ' + ISNULL(CAST(@fp_in_cuotas AS VARCHAR),'0') + ';' 
							FETCH NEXT FROM curItemFPs INTO @fp_id_fp, @fp_id_tc, @fp_cd_codigo, @fp_ds_nombre, @fp_cd_tipotarjeta, @fp_ds_numerotarjeta, @fp_ds_vouchertarjeta, @fp_ds_expiraciontarjeta, @fp_ds_autorizaciontarjeta, @fp_in_cuotas, @fp_am_valor;
						END
						CLOSE curItemFPs;
						DEALLOCATE curItemFPs;

						-- Build Itinerarios SQL (inline query, no temp table needed)
						SET @TktItinSqlStmt = '';
						SELECT 
							@TktItinSqlStmt = @TktItinSqlStmt + + CHAR(13) + CHAR(10) + 
							'EXECUTE dbo.spza_TiqueteItinerarios_Insertar 
								@id_fac_factura = @NewFacId, 
								@id_fac_remision = @NewRmId, 
								@id_Tiquetes = @NewTktId, 
								@orden = ' + CAST(orden AS VARCHAR) + ', 
								@cd_origen = ''' + ISNULL(cd_origen,'') + ''', 
								@cd_destino = ''' + ISNULL(cd_destino,'') + ''', 
								@cd_clase = ''' + ISNULL(cd_clase,'') + ''', 
								@fecha_salida = ''' + ISNULL(CONVERT(VARCHAR(10),fecha_salida,111),'') + ''', 
								@hora_salida = ''' + ISNULL(hora_salida,'') + ''', 
								@hora_llegada = ''' + ISNULL(hora_llegada,'') + ''', 
								@terminal = ''' + REPLACE(ISNULL(terminal,''), '''', '''''') + ''', 
								@cd_aero_siglas = ''' + ISNULL(cd_aero_siglas,'') + ''', 
								@cd_farebasis = ''' + ISNULL(cd_farebasis,'') + ''', 
								@ds_NumVuelo = ''' + ISNULL(ds_NumVuelo,'') + ''', 
								@ds_TipoVuelo = ''' + ISNULL(ds_TipoVuelo,'') + ''', 
								@am_valor = ' + CAST(ISNULL(am_valor, 0) AS VARCHAR) + ', 
								@bl_NoUtilizado = NULL, 
								@am_co2 = ' + CAST(ISNULL(am_co2, 0) AS VARCHAR) + '; '
						FROM dbo.ReservaGDS_Itinerarios
						WHERE id_reserva = @gen_id_air
						ORDER BY Orden;

						SET @SqlStmt = @SqlStmt + CHAR(13) + CHAR(10) + '
						DECLARE @NewTktId_' + CAST(@ItemIndex AS VARCHAR) + ' INT;
						EXECUTE dbo.spza_Tiquete_Vender
							@cd_tiquete = ''' + @gen_cd_tiquete + ''',
							@id_TiposDocumento = ' + CAST(@gen_id_TiposDocumento AS VARCHAR) + ',
							@id_entdist = ' + CAST(@gen_id_entdist AS VARCHAR) + ',
							@in_estado = 1,
							@in_nacionalidad = ' + CAST(@gen_in_nacionalidad AS VARCHAR) + ',
							@id_entvend = ' + CAST(@gen_id_entvend AS VARCHAR) + ',
							@id_fac_factura = @NewFacId,
							@id_fac_remision = @NewRmId,
							@cd_tktrevisado = ' + ISNULL('''' + @gen_cd_tktrevisado + '''', 'NULL') + ',
							@id_pax = NULL,
							@ds_paxname = ''' + @gen_ds_paxname + ''',
							@ds_paxape = ''' + @gen_ds_paxape + ''',
							@ds_paxprefix = ''' + ISNULL(@gen_ds_paxprefix, '') + ''',
							@cd_paxcedula = ''' + ISNULL(@gen_cd_pax_CC, '') + ''',
							@ds_itinerario = ''' + LEFT(@gen_ds_itinerario, 63) + ''',
							@ds_itinerarioaerolinea = ''' + LEFT(ISNULL(@gen_ds_itinerarioaerolinea, ''), 63) + ''',
							@ds_clases = ''' + ISNULL(@gen_ds_clases, '') + ''',
							@dt_fechasalida = ' + ISNULL('''' + CONVERT(VARCHAR, @gen_Fecha_Salida, 120) + '''', 'NULL') + ',
							@dt_fechallegada = ' + ISNULL('''' + CONVERT(VARCHAR, @gen_Fecha_Llegada, 120) + '''', 'NULL') + ',
							@cd_destino = ''' + ISNULL(@gen_cd_destino, '') + ''',
							@dt_fechaexped = ''' + CONVERT(VARCHAR, @gen_dt_fechaexped, 120) + ''',
							@id_usuario = 1,
							@id_tiqueteadores = ' + CAST(@gen_id_tiqueteadores AS VARCHAR) + ',
							@am_hf = ' + CAST(@gen_am_highfare AS VARCHAR) + ',
							@am_lf = ' + CAST(@gen_am_lowfare AS VARCHAR) + ',
							@am_tarifa = ' + CAST(@gen_am_tarifa AS VARCHAR) + ',
							@cd_ah = ''' + ISNULL(@gen_cd_tourcode, '') + ''',
							@am_desah = 0,
							@id_gds = ' + CAST(@gen_id_gds AS VARCHAR) + ',
							@iden_gds = ' + CAST(@gen_iden_gds AS VARCHAR) + ',
							@in_numtktconj = ' + CAST(@gen_NumTktConj AS VARCHAR) + ',
							@bl_NoCalcComision = 0,
							@bl_NoCalcIvaComision = 0,
							@am_comisionPNR = ' + CAST(@gen_am_Comision AS VARCHAR) + ',
							@am_basecomisionable = ' + CAST(@gen_am_tarifa AS VARCHAR) + ',
							@am_porcomision = 0,
							@ds_records = ''' + @gen_ds_records + ''',
							@id_hotel = NULL,
							@id_precompra = ' + ISNULL(CAST(@gen_Id_Precompra AS VARCHAR), 'NULL') + ',
							@id_TipoTiquete = NULL,
							@id_ReassonCode = NULL,
							@cencosto_interno = ''' + ISNULL(@gen_cd_cencosto, '') + ''',
							@ds_solicita = ''' + ISNULL(@gen_ds_solicita, '') + ''',
							@ds_lapsoviaje = ''' + ISNULL(@gen_ds_lapsoviaje, '') + ''',
							@id_monedas_iata = @id_monedas_iata,
							@Tcambio = @Tcambio,
							@cd_TiqueteGr = NULL,
							@SqlStmt = ''' + REPLACE(@TktSqlStmt, '''', '''''') + ''',
							@SqlStmtItinerarios = ''' + REPLACE(@TktItinSqlStmt, '''', '''''') + ''',
							@id_sucursal = @id_sucursal,
							@id_implante = @id_implante,
							@bl_ahorro = ' + CAST(@gen_bl_ahorro AS VARCHAR) + ',
							@cd_TipoTiqueteGDS = ''' + ISNULL(@gen_cd_TipoTiqueteGDS, '') + ''',
							@cd_tourcode = ''' + ISNULL(@gen_cd_tourcode, '') + ''',
							@cd_PasaportePax = ''' + ISNULL(@gen_cd_PasaportePax, '') + ''',
							@am_valor_aerolinea = ' + CAST(@gen_am_tarifa AS VARCHAR) + ',
							@am_porcentaje_comision_BackEnd = 0,
							@am_valor_comision_BackEnd = 0,
							@am_PorFacParcial = ' + CAST(ISNULL(@gen_am_PorFacParcial, 100) AS VARCHAR) + ',
							@in_cantpax = ' + CAST(ISNULL(@gen_in_cantpax, 1) AS VARCHAR) + ',
							@OrdenGrabacion = ' + CAST(ISNULL(@ItemIndex, 1) AS VARCHAR) + ',
							@cd_Penalidad = NULL,
							@id_entdistIata = NULL,
							@id_entvendIata = NULL; ';
					END
					ELSE IF @gen_tipo_item = 'TAO'
					BEGIN 
						-- Build cargos / impuestos SQL
						SET @TaoCargSqlStmt = '';
						
						DECLARE @tc_codigo VARCHAR(20), @tc_ds_nombre VARCHAR(100), @tc_cd_tipo CHAR(1), @tc_am_porcentaje NUMERIC(8,4), @tc_am_valor MONEY, @tc_am_contado MONEY, @tc_am_credito MONEY, @tc_id_carg INT, @tc_id_imp INT;
						
						DECLARE @TaoImpuestosSqlStmt VARCHAR(MAX) = '';
												
						DECLARE curItemTaoCargos CURSOR LOCAL FAST_FORWARD FOR
						SELECT cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp
						FROM #TmpFacturaCargos
						WHERE id_item = @gen_id_item AND cd_tipo IN ('C','D');

						OPEN curItemTaoCargos;
						FETCH NEXT FROM curItemTaoCargos INTO @tc_codigo, @tc_ds_nombre, @tc_cd_tipo, @tc_am_porcentaje, @tc_am_valor, @tc_am_contado, @tc_am_credito, @tc_id_carg, @tc_id_imp;
						WHILE @@FETCH_STATUS = 0
						BEGIN
							DECLARE @tc_codigotax VARCHAR(20), @tc_ds_nombretax VARCHAR(100), @tc_cd_tipotax CHAR(1), @tc_am_porcentajetax NUMERIC(8,4), @tc_am_valortax MONEY, @tc_am_contadotax MONEY, @tc_am_creditotax MONEY, @tc_id_cargtax INT, @tc_id_imptax INT;
							SET @TaoImpuestosSqlStmt='';

							DECLARE curItemTaoTaxes CURSOR LOCAL FAST_FORWARD FOR
							SELECT cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp
							FROM #TmpFacturaCargos
							WHERE id_item = @gen_id_item AND id_carg=@tc_id_carg AND cd_tipo IN ('I','R');

							OPEN curItemTaoTaxes;
							FETCH NEXT FROM curItemTaoTaxes INTO @tc_codigotax, @tc_ds_nombretax, @tc_cd_tipotax, @tc_am_porcentajetax, @tc_am_valortax, @tc_am_contadotax, @tc_am_creditotax, @tc_id_cargtax, @tc_id_imptax;	
							WHILE @@FETCH_STATUS = 0
							BEGIN
								SET @TaoImpuestosSqlStmt = @TaoImpuestosSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_TaoImpuestos_Insertar @id_FacTaoCargos = @NewCargId, @id_impret = ' + CAST(ISNULL(@tc_id_imptax, 1) AS VARCHAR) + ', @ds_impas = ''' + ISNULL(@tc_ds_nombretax,'') + ''', @cd_impcta='''', @am_valor = ' + CAST(ISNULL(@tc_am_valortax,0) AS VARCHAR) + ', @am_contado = ' + CAST(ISNULL(@tc_am_contadotax,0) AS VARCHAR) + ', @am_credito = ' + CAST(ISNULL(@tc_am_creditotax,0) AS VARCHAR) + ', @am_porcentaje=' + CAST(ISNULL(@tc_am_porcentajetax,0) AS VARCHAR) + ', @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @bl_contabilizar=1;' 
								FETCH NEXT FROM curItemTaoTaxes INTO @tc_codigotax, @tc_ds_nombretax, @tc_cd_tipotax, @tc_am_porcentajetax, @tc_am_valortax, @tc_am_contadotax, @tc_am_creditotax, @tc_id_cargtax, @tc_id_imptax;
							END
							CLOSE curItemTaoTaxes;
							DEALLOCATE curItemTaoTaxes;

							SET @TaoCargSqlStmt = @TaoCargSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_TaoCargos_Insertar @id_fac_remision = @NewRmId, @id_fac_factura = @NewFacId, @Id_Fac_Tao = @NewTaoId, @id_cargosdesc = ' + CAST(ISNULL(@tc_id_carg, 1) AS VARCHAR) + ', @ds_cargonm = ''' + ISNULL(@tc_ds_nombre,'') + ''', @am_valor = ' + CAST(ISNULL(@tc_am_valor,0) AS VARCHAR) + ', @am_contado = ' + CAST(ISNULL(@tc_am_contado,0) AS VARCHAR) + ', @am_credito = ' + CAST(ISNULL(@tc_am_credito,0) AS VARCHAR) + ', @bl_noshow = 0, @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @SqlStmt = ''' + REPLACE(ISNULL(@TaoImpuestosSqlStmt,''), '''', '''''') + ''';' 
							FETCH NEXT FROM curItemTaoCargos INTO @tc_codigo, @tc_ds_nombre, @tc_cd_tipo, @tc_am_porcentaje, @tc_am_valor, @tc_am_contado, @tc_am_credito, @tc_id_carg, @tc_id_imp;
						END
						CLOSE curItemTaoCargos;
						DEALLOCATE curItemTaoCargos;
						
						SET @TaoFpSqlStmt = '';
						
						DECLARE @tfp_id_fp INT, @tfp_id_tc INT, @tfp_cd_codigo VARCHAR(10), @tfp_ds_nombre VARCHAR(50), @tfp_cd_tipotarjeta VARCHAR(10), @tfp_ds_numerotarjeta VARCHAR(50), @tfp_ds_vouchertarjeta VARCHAR(50), @tfp_ds_expiraciontarjeta VARCHAR(10), @tfp_ds_autorizaciontarjeta VARCHAR(50), @tfp_in_cuotas INT, @tfp_am_valor MONEY;
						DECLARE curItemTaoFPs CURSOR LOCAL FAST_FORWARD FOR
						SELECT id_formaspago, id_tarjetascredito, cd_codigo, ds_nombre, cd_tipotarjeta , ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_cuotas, am_valor
						FROM #TmpFacturaFormasPago
						WHERE id_item = @gen_id_item;

						OPEN curItemTaoFPs;
						FETCH NEXT FROM curItemTaoFPs INTO @tfp_id_fp, @tfp_id_tc, @tfp_cd_codigo, @tfp_ds_nombre, @tfp_cd_tipotarjeta, @tfp_ds_numerotarjeta, @tfp_ds_vouchertarjeta, @tfp_ds_expiraciontarjeta, @tfp_ds_autorizaciontarjeta, @tfp_in_cuotas, @tfp_am_valor;
						WHILE @@FETCH_STATUS = 0
						BEGIN
							SET @TaoFpSqlStmt = @TaoFpSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_TaoFormasPago_Insertar @Id_Fac_Tao = @NewTaoId, @id_fac_factura = @NewFacId, @id_fac_remision = @NewRmId, @id_formaspago = ' + CAST(@tfp_id_fp AS VARCHAR) + ', @ds_fpnm = ''' + REPLACE(@tfp_ds_nombre, '''', '''''') + ''', @bl_fprepresenta = 0, @id_tarjetascredito = ' + ISNULL(CAST(@tfp_id_tc AS VARCHAR), 'NULL') + ', @cd_tccode = ' + ISNULL('''' + @tfp_cd_tipotarjeta + '''', 'NULL') + ', @ds_tcnumber = ' + ISNULL('''' + @tfp_ds_numerotarjeta + '''', 'NULL') + ', @ds_tcvoucher = ' + ISNULL('''' + @tfp_ds_vouchertarjeta + '''', 'NULL') + ', @ds_tcexp = ' + ISNULL('''' + @tfp_ds_expiraciontarjeta + '''', 'NULL') + ', @cd_idbanco = NULL, @ds_cheque = NULL, @ds_plaza = NULL, @ds_referencia = NULL, @ds_poliza = NULL, @ds_polanexo = NULL, @am_valor = ' + CAST(@tfp_am_valor AS VARCHAR) + ', @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @ds_tcautorizacion = ' + ISNULL('''' + @tfp_ds_autorizaciontarjeta + '''', 'NULL') + ', @in_tccuotas = ' + ISNULL(CAST(@tfp_in_cuotas AS VARCHAR), '0') + ';' 
							FETCH NEXT FROM curItemTaoFPs INTO @tfp_id_fp, @tfp_id_tc, @tfp_cd_codigo, @tfp_ds_nombre, @tfp_cd_tipotarjeta, @tfp_ds_numerotarjeta, @tfp_ds_vouchertarjeta, @tfp_ds_expiraciontarjeta, @tfp_ds_autorizaciontarjeta, @tfp_in_cuotas, @tfp_am_valor;
						END
						CLOSE curItemTaoFPs;
						DEALLOCATE curItemTaoFPs;

						SET @SqlStmt = @SqlStmt + CHAR(13) + CHAR(10) +'
						DECLARE @NewTaoId_' + CAST(@ItemIndex AS VARCHAR) + ' INT;
						EXECUTE dbo.spza_Tao_Vender
							@cd_tiquete = ''' + ISNULL(@gen_cd_tiquete, '') + ''',
							@ds_descrip = ''' + ISNULL(@gen_ds_descrip, '') + ''',
							@id_fac_factura = @NewFacId,
							@id_fac_remision = @NewRmId,
							@in_nacionalidad = ' + CAST(ISNULL(@gen_in_nacionalidad,0) AS VARCHAR) + ',
							@cd_cencosto = ''' + ISNULL(@gen_cd_cencosto, '') + ''',
							@cd_aux = ''' + ISNULL(@gen_cd_auxiliar, '') + ''',
							@cd_coditem = ''' + ISNULL(@gen_cd_item, '') + ''',
							@am_basecomisionable = ' + CAST(ISNULL(@gen_am_tarifa,0) AS VARCHAR) + ',
							@am_porcomision = 0,
							@id_monedas_iata = @id_monedas_iata,
							@Tcambio = @Tcambio,
							@OrdenGrabacion = ' + CAST(@ItemIndex AS VARCHAR) + ',
							@SqlStmt = ''' + REPLACE(@TaoCargSqlStmt + @TaoFpSqlStmt, '''', '''''') + '''; '

							
					END
					ELSE IF @gen_tipo_item IN ('SRV','Hotel','Auto')
					BEGIN
						-- Build cargos / impuestos / provider / pax SQL
						SET @SrvSqlStmt = '';
						SET @SrvImpuestosSqlStmt = '';
						
						DELETE FROM #TmpVariablesObtenidas;
						IF @gen_id_referencia_origen IS NOT NULL
						BEGIN
							INSERT INTO #TmpVariablesObtenidas
							EXEC dbo.spza_ConfiguracionVariablesJOB_ObtenerValores 
								@id_usuario = 1, 
								@id_ReservaGDS_Servicios = @gen_id_referencia_origen;

							DECLARE @var_Iden_Variable_srv INT, @var_IDEN_Maestro_srv INT, @var_ValorObtenido_srv VARCHAR(MAX);
							DECLARE curVarsSrv CURSOR LOCAL FAST_FORWARD FOR
							SELECT Iden_Variable, IDEN_Maestro, ValorObtenido FROM #TmpVariablesObtenidas WHERE ISNULL(ValorObtenido, '') <> '';

							OPEN curVarsSrv;
							FETCH NEXT FROM curVarsSrv INTO @var_Iden_Variable_srv, @var_IDEN_Maestro_srv, @var_ValorObtenido_srv;
							WHILE @@FETCH_STATUS = 0
							BEGIN
								SET @SrvSqlStmt = @SrvSqlStmt +CHAR(13) + CHAR(10)+ ' INSERT INTO dbo.VariableDatosMaestro (Iden_Variable, IDEN_Maestro, cd_maestro, ValorObtenido) VALUES (' + CAST(@var_Iden_Variable_srv AS VARCHAR) + ', ' + CAST(@var_IDEN_Maestro_srv AS VARCHAR) + ', ''' + REPLACE(@gen_cd_Consecutivo_variablesadicionales, '''', '''''') + ''', ''' + REPLACE(@var_ValorObtenido_srv, '''', '''''') + ''');' 
								FETCH NEXT FROM curVarsSrv INTO @var_Iden_Variable_srv, @var_IDEN_Maestro_srv, @var_ValorObtenido_srv;
							END;
							CLOSE curVarsSrv;
							DEALLOCATE curVarsSrv;
						END
						SET @SrvCargSqlStmt = '';
						SET @SrvFpSqlStmt = '';

						DECLARE @sc_codigo VARCHAR(20), @sc_ds_nombre VARCHAR(100), @sc_cd_tipo CHAR(1), @sc_am_porcentaje NUMERIC(8,4), @sc_am_valor MONEY, @sc_am_contado MONEY, @sc_am_credito MONEY, @sc_id_carg INT, @sc_id_imp INT;
						DECLARE @HasTarCargo BIT, @IsFirstCargo BIT;
						
						-- First Pass: accumulate service taxes (impuestos/retenciones)
						-- Second Pass: process cargos and link accumulated taxes to 'TAR' or first cargo
						DECLARE curItemSrvCargos CURSOR LOCAL FAST_FORWARD FOR
						SELECT cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp
						FROM #TmpFacturaCargos
						WHERE id_item = @gen_id_item AND cd_tipo IN ('C','D');
						

						OPEN curItemSrvCargos;
						FETCH NEXT FROM curItemSrvCargos INTO @sc_codigo, @sc_ds_nombre, @sc_cd_tipo, @sc_am_porcentaje, @sc_am_valor, @sc_am_contado, @sc_am_credito, @sc_id_carg, @sc_id_imp;
						WHILE @@FETCH_STATUS = 0
						BEGIN
							DECLARE @sc_codigotax VARCHAR(20), @sc_ds_nombretax VARCHAR(100), @sc_cd_tipotax CHAR(1), @sc_am_porcentajetax NUMERIC(8,4), @sc_am_valortax MONEY, @sc_am_contadotax MONEY, @sc_am_creditotax MONEY, @sc_id_cargtax INT, @sc_id_imptax INT;
							SET @SrvImpuestosSqlStmt='';
							DECLARE curItemSrvTaxes CURSOR LOCAL FAST_FORWARD FOR
							SELECT cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp
							FROM #TmpFacturaCargos
							WHERE id_item = @gen_id_item AND id_carg=@sc_id_carg AND cd_tipo IN ('I','R');

							OPEN curItemSrvTaxes;
							FETCH NEXT FROM curItemSrvTaxes INTO @sc_codigotax, @sc_ds_nombretax, @sc_cd_tipotax, @sc_am_porcentajetax, @sc_am_valortax, @sc_am_contadotax, @sc_am_creditotax, @sc_id_cargtax, @sc_id_imptax;
							WHILE @@FETCH_STATUS = 0
							BEGIN
								SET @SrvImpuestosSqlStmt = @SrvImpuestosSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_ServicioImpuestos_Insertar @id_FacServiciosCargos = @NewCargId, @id_impret = ' + CAST(ISNULL(@sc_id_imptax, 1) AS VARCHAR) + ', @ds_impas = ''' + ISNULL(@sc_ds_nombretax, '') + ''', @cd_impcta = '''', @am_valor = ' + CAST(ISNULL(@sc_am_valortax,0) AS VARCHAR) + ', @am_contado = ' + CAST(ISNULL(@sc_am_contadotax,0) AS VARCHAR) + ', @am_credito = ' + CAST(ISNULL(@sc_am_creditotax,0) AS VARCHAR) + ', @am_porcentaje = ' + CAST(ISNULL(@sc_am_porcentajetax,0) AS VARCHAR) + ', @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @bl_contabilizar = 1, @am_deltaCorreccion = 0;' 
								
								FETCH NEXT FROM curItemSrvTaxes INTO @sc_codigotax, @sc_ds_nombretax, @sc_cd_tipotax, @sc_am_porcentajetax, @sc_am_valortax, @sc_am_contadotax, @sc_am_creditotax, @sc_id_cargtax, @sc_id_imptax;
							END
							CLOSE curItemSrvTaxes;
							DEALLOCATE curItemSrvTaxes;

							SET @SrvCargSqlStmt = @SrvCargSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_ServicioCargos_Insertar @id_Fac_Servicios = @NewSrvId, @id_cargosdesc = ' + CAST(ISNULL(@sc_id_carg, 1) AS VARCHAR) + ', @ds_cargonm = ''' + ISNULL(@sc_ds_nombre, '') + ''', @am_valor = ' + CAST(ISNULL(@sc_am_valor,0) AS VARCHAR) + ', @am_contado = ' + CAST(ISNULL(@sc_am_contado,0) AS VARCHAR) + ', @am_credito = ' + CAST(ISNULL(@sc_am_credito,0) AS VARCHAR) + ', @bl_noshow = 0, @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @SqlStmt = ''' + REPLACE(ISNULL(@SrvImpuestosSqlStmt,''), '''', '''''') + ''';' 
							
							FETCH NEXT FROM curItemSrvCargos INTO @sc_codigo, @sc_ds_nombre, @sc_cd_tipo, @sc_am_porcentaje, @sc_am_valor, @sc_am_contado, @sc_am_credito, @sc_id_carg, @sc_id_imp;
						END
						CLOSE curItemSrvCargos;
						DEALLOCATE curItemSrvCargos;
						 
						-- Build Formas de Pago SQL
						DECLARE @sfp_id_fp INT, @sfp_id_tc INT, @sfp_cd_codigo VARCHAR(10), @sfp_ds_nombre VARCHAR(50), @sfp_cd_tipotarjeta VARCHAR(10), @sfp_ds_numerotarjeta VARCHAR(50), @sfp_ds_vouchertarjeta VARCHAR(50), @sfp_ds_expiraciontarjeta VARCHAR(10), @sfp_ds_autorizaciontarjeta VARCHAR(50), @sfp_in_cuotas INT, @sfp_am_valor MONEY;
						DECLARE curItemSrvFPs CURSOR LOCAL FAST_FORWARD FOR
						SELECT id_formaspago, id_tarjetascredito, cd_codigo, ds_nombre, cd_tipotarjeta, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_cuotas, am_valor
						FROM #TmpFacturaFormasPago
						WHERE id_item = @gen_id_item;

						OPEN curItemSrvFPs;
						FETCH NEXT FROM curItemSrvFPs INTO @sfp_id_fp, @sfp_id_tc, @sfp_cd_codigo, @sfp_ds_nombre, @sfp_cd_tipotarjeta, @sfp_ds_numerotarjeta, @sfp_ds_vouchertarjeta, @sfp_ds_expiraciontarjeta, @sfp_ds_autorizaciontarjeta, @sfp_in_cuotas, @sfp_am_valor;
						WHILE @@FETCH_STATUS = 0
						BEGIN
							SET @SrvFpSqlStmt = @SrvFpSqlStmt + CHAR(13) + CHAR(10) +' EXECUTE dbo.spza_ServicioFormasPago_Insertar @id_Fac_Servicios = @NewSrvId, @id_fac_factura = @NewFacId, @id_fac_remision = @NewRmId, @id_formaspago = ' + CAST(@sfp_id_fp AS VARCHAR) + ',@ds_fpnm =' + ISNULL('''' + @sfp_ds_nombre + '''', 'NULL') + ', @am_valor = ' + CAST(@sfp_am_valor AS VARCHAR) + ',@bl_fprepresenta=0 , @id_tarjetascredito = ' + ISNULL(CAST(@sfp_id_tc AS VARCHAR), 'NULL') + ', @cd_tccode = ' + ISNULL(CAST(@sfp_cd_tipotarjeta AS VARCHAR), 'NULL') + ', @ds_tcnumber = ' + ISNULL('''' + @sfp_ds_numerotarjeta + '''', 'NULL') + ', @ds_tcvoucher = ' + ISNULL('''' + @sfp_ds_vouchertarjeta + '''', 'NULL') + ', @ds_tcexp = ' + ISNULL('''' + @sfp_ds_expiraciontarjeta + '''', 'NULL') + ', @ds_tcautorizacion = ' + ISNULL('''' + @sfp_ds_autorizaciontarjeta + '''', 'NULL') + ', @in_tccuotas = ' + ISNULL(CAST(@sfp_in_cuotas AS VARCHAR),'0') + ', @cd_idbanco=NULL, @ds_cheque=NULL,@ds_plaza=NULL,@ds_referencia=NULL, @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio;' 
							FETCH NEXT FROM curItemSrvFPs INTO @sfp_id_fp, @sfp_id_tc, @sfp_cd_codigo, @sfp_ds_nombre, @sfp_cd_tipotarjeta, @sfp_ds_numerotarjeta, @sfp_ds_vouchertarjeta, @sfp_ds_expiraciontarjeta, @sfp_ds_autorizaciontarjeta, @sfp_in_cuotas, @sfp_am_valor;
						END
						CLOSE curItemSrvFPs;
						DEALLOCATE curItemSrvFPs;

						-- Build provider SQL
						SET @SrvProvSqlStmt = '';
						DECLARE @c_id_tipoproveedor INT, @c_cd_tipoproveedor VARCHAR(10), @c_ds_tipoproveedor VARCHAR(100);
						IF ISNULL(@gen_cd_proveedores, '') <> ''
						BEGIN
							SELECT TOP 1 
								@c_id_tipoproveedor = tp.id, 
								@c_cd_tipoproveedor = tp.cd_codigo, 
								@c_ds_tipoproveedor = tp.ds_nombre 
							FROM dbo.TipoProveedores tp WITH(NOLOCK) 
							WHERE tp.cd_codigo = 'HTL';
							
							IF @c_id_tipoproveedor IS NOT NULL
							BEGIN
								SET @SrvProvSqlStmt = CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_ServicioTipoProv_Insertar @id_Fac_Servicios = @NewSrvId, @id_tipoproveedor = ' + CAST(@c_id_tipoproveedor AS VARCHAR) + ', @cd_TipoProveedores = ''' + ISNULL(@c_cd_tipoproveedor,'') + ''', @ds_TipoProveedores = ''' + ISNULL(@c_ds_tipoproveedor,'')+ ''', @cd_proveedores = ''' + ISNULL(@c_cd_proveedores,'')+''', @ds_proveedores = ''' + ISNULL(@c_ds_proveedores,'')+ ''''';'
							END;
						END;

						-- Build pax SQL
						SET @SrvPaxSqlStmt = '';
						IF ISNULL(@gen_ds_paxname, '') <> ''
						BEGIN
							SET @SrvPaxSqlStmt = CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_ServicioPaxAdicional_insertar @FacId = @NewFacId, @RemId = @NewRemId, @id_Fac_Servicios = @NewSrvId, @ds_paxname = ''' + REPLACE(@gen_ds_paxname, '''', '''''') + ''', @ds_paxape = ''' + REPLACE(@gen_ds_paxape, '''', '''''') + ''', @in_edad = NULL, @ds_paxprefix= ''' + @gen_ds_paxprefix + ''', @ds_paxClasificacion = NULL, @cd_voucherpax=NULL, @cd_tiquete=NULL;'
						END;

						SET @SrvSqlStmt = @SrvCargSqlStmt + @SrvFpSqlStmt + @SrvProvSqlStmt;
						
						SET @SqlStmt = @SqlStmt + CHAR(13) + CHAR(10) + '
						DECLARE @NewSrvId_' + CAST(@ItemIndex AS VARCHAR) + ' INT;
						EXECUTE dbo.spza_Servicio_Vender
							@ds_descrip = ''' + ISNULL(@gen_ds_descrip, '') + ''',
							@id_fac_factura = @NewFacId,
							@id_fac_remision = @NewRmId,
							@id_CotizacionServicios = NULL,
							@in_nacionalidad = ' + CAST(ISNULL(@gen_in_nacionalidad,1) AS VARCHAR) + ',
							@cd_cencosto = ' + CASE WHEN ISNULL(@gen_cd_cencosto, '')='' THEN 'NULL' ELSE '' + ISNULL(@gen_cd_cencosto, '') + '' END + ',
							@cd_auxiliar = ''' + ISNULL(@gen_cd_auxiliar, '') + ''',
							@cd_item = ''' + ISNULL(@gen_cd_item, '') + ''',
							@id_tiposconceptfac = ' + ISNULL(CAST(@gen_id_tiposconceptfac AS VARCHAR), 'NULL') + ',
							@id_conceptofacturacion = ' + ISNULL(CAST(@gen_id_conceptofacturacion AS VARCHAR), 'NULL') + ',
							@id_tiposservicio = ' + ISNULL(CAST(@gen_id_tiposservicio AS VARCHAR), 'NULL') + ',
							@cd_tiquete = ' + ISNULL('''' + @gen_cd_tiquete + '''', 'NULL') + ',
							@id_voucherstocks = NULL,
							@cd_voucherPrefijo = NULL,
							@cd_proveedores = ''' + ISNULL(@gen_cd_proveedores, '') + ''',
							@ds_tiposervnm = ''' + ISNULL(@gen_ds_servicio, '') + ''',
							@cd_prov_hotel = NULL,
							@cd_prov_car = NULL,
							@cd_prov_air = NULL,
							@ds_servicio = ''' + ISNULL(@gen_ds_servicio, '') + ''',
							@am_valorprov = ' + CAST(ISNULL(@gen_am_tarifa,0) AS VARCHAR) + ',
							@id_monedaprov = ' + ISNULL(CAST(@id_monedas_iata AS VARCHAR), 'NULL') + ',
							@ds_InfoAdicional = NULL,
							@ds_paxname = ''' + ISNULL(@gen_ds_paxname, '') + ''',
							@ds_paxape = ''' + ISNULL(@gen_ds_paxape, '') + ''',
							@cd_paxtype = ''' + ISNULL(@gen_ds_paxprefix, '') + ''',
							@in_edad = NULL,
							@cd_voucher = NULL,
							@in_cantpax = 1,
							@dt_llegada = ' + ISNULL('''' + CONVERT(VARCHAR, @gen_Fecha_Llegada, 120) + '''', 'NULL') + ',
							@dt_salida = ' + ISNULL('''' + CONVERT(VARCHAR, @gen_Fecha_Salida, 120) + '''', 'NULL') + ',
							@ds_destino = ''' + ISNULL(@gen_cd_destino, '') + ''',
							@id_gds = '+ CAST(ISNULL(@gen_id_gds,1) AS VARCHAR) + ',
							@am_basecomisionable = ' + CAST(ISNULL(@gen_am_basecomisionable,0) AS VARCHAR) + ',
							@am_porcomision = 0,
							@id_tipoplan = NULL,
							@id_acomodacion = NULL,
							@ds_paxClasificacion = NULL,
							@in_dias = NULL,
							@in_noches = NULL,
							@bl_notdomicilionacional=0,
							@CodigoReserva =''' + ISNULL(@gen_ds_records,'') + ''',
							@AnticiposSqlStmt = NULL,
							@PaxAdicionalSqlStmt = ''' + REPLACE(ISNULL(@SrvPaxSqlStmt,''), '''', '''''') + ''', 
							@VoucherAdicionalSqlStmt = NULL,
							@id_monedas_iata = @id_monedas_iata,
							@Tcambio = @Tcambio,
							@Id_GrConcepto = NULL,
							@in_diasSrv = NULL,
							@in_nochesSrv = NULL,
							@OrdenGrabacion = ' + CAST(@ItemIndex AS VARCHAR) + ',
							@Id_Especialista = NULL,
							@am_porcentaje_descuento = ' + CAST(ISNULL(@gen_am_pordescuento, 0) AS VARCHAR) + ',
							@am_valor_descuento = 0,
							@ds_motivo_descuento = NULL,
							@Id_CargosDesc_Descuento = NULL,
							@dt_FechaSalidaSrv = ' + ISNULL('''' + CONVERT(VARCHAR, @gen_Fecha_Salida, 120) + '''', 'NULL') + ',
							@dt_FechaLlegadaSrv = ' + ISNULL('''' + CONVERT(VARCHAR, @gen_Fecha_Llegada, 120) + '''', 'NULL') + ',
							@cd_localizador = NULL,
							@cd_VoucherPax = NULL,
							@am_basecomisionableprov = ' + CAST(ISNULL(@gen_am_basecomisionable,0) AS VARCHAR) + ',
							@am_porcomisionprov = 0,
							@cd_NumeFac = NULL,
							@dt_VenceFac = NULL,
							@Id_AcomodacionSrv = NULL,
							@Id_TipoPlanSrv = NULL,
							@in_habitaciones = NULL,
							@in_habitacionesSrv = NULL,
							@SqlStmt = ''' + REPLACE(@SrvSqlStmt, '''', '''''') + ''',
							@cd_Consecutivo_variablesadicionales = ' + ISNULL('''' + @gen_cd_Consecutivo_variablesadicionales + '''', 'NULL') + ',
							@cd_confirmacion = NULL,
							@ds_confirmadopor = NULL,
							@cd_paxidentificacion = NULL,
							@bl_politicaCancelacion = 0,
							@dt_politicaCancelacion = NULL,
							@id_tipoHabitacion = NULL,
							@cd_Consecutivo_depende = ' + ISNULL('''' + @gen_cd_Consecutivo_depende + '''', 'NULL') + ',
							@id_TarjetaAsistencia = NULL,
							@id_Regiones = NULL,
							@Iden_GDS = NULL,
							@id_sys_entidades = 108,
							@ds_TipoAuto = NULL,
							@ds_Origen = NULL,
							@ds_DirOrigen = NULL,
							@ds_DirDestino = NULL,
							@ds_TipoTarifa = NULL,
							@am_ValorUSD = NULL,
							@ds_NoVuelo = NULL,
							@ds_Vehiculo = NULL,
							@ds_Placa = NULL,
							@ds_CategoriaVehiculo = NULL,
							@ds_NombreConductor = NULL,
							@ds_telefono = NULL,
							@ds_IdiomaConductor = NULL,
							@id_MonedaSrv = ' + ISNULL(CAST(@gen_id_monedaprov AS VARCHAR), 'NULL') + ',
							@id_TipoServicio = NULL,
							@id_Aerolinea = NULL,
							@am_PorFacParcial = 100,
							@ds_GDS = NULL,
							@am_basedescuento = ' + CAST(ISNULL(@gen_am_basedescuento, 0) AS VARCHAR) + ',
							@am_pordescuento = ' + CAST(ISNULL(@gen_am_pordescuento, 0) AS VARCHAR) + '; '

					END;
					SET @ItemIndex = @ItemIndex + 1;
					FETCH NEXT FROM curGenItems INTO 
						@gen_id_item, @gen_tipo_item, @gen_cd_tiquete, @gen_ds_descrip, @gen_in_nacionalidad, @gen_cd_cencosto, @gen_cd_auxiliar, @gen_cd_item, @gen_am_tarifa, @gen_am_iva, @gen_am_tua, @gen_am_comb, @gen_am_vat, @gen_am_Comision,
						@gen_ds_paxname, @gen_ds_paxape, @gen_ds_paxprefix, @gen_cd_tourcode, @gen_NumTktConj, @gen_cd_TipoTiquete, @gen_id_air, @gen_ds_itinerario, @gen_ds_itinerarioaerolinea, @gen_ds_clases, @gen_ds_Observaciones,
						@gen_am_highfare, @gen_am_lowfare, @gen_ds_solicita, @gen_ds_lapsoviaje, @gen_cd_tktrevisado, @gen_cd_PasaportePax, @gen_cd_pax_CC, @gen_am_PorFacParcial, @gen_in_cantpax, @gen_Id_Precompra,
						@gen_id_FormasPago, @gen_id_TarjetasCredito, @gen_id_sucursal, @gen_id_implante, @gen_bl_ahorro, @gen_cd_TipoTiqueteGDS, @gen_id_TiposDocumento, @gen_id_entdist, @gen_id_entvend,
						@gen_cd_destino, @gen_dt_fechaexped, @gen_id_tiqueteadores, @gen_id_gds, @gen_iden_gds, @gen_am_comisionPNR, @gen_ds_records, @gen_bl_NoCalcComision, @gen_bl_NoCalcIvaComision,
						@gen_am_basecomisionable, @gen_am_porcomision, @gen_id_tiposconceptfac, @gen_id_conceptofacturacion, @gen_id_tiposservicio, @gen_cd_proveedores, @gen_ds_servicio,
						@gen_am_valorprov, @gen_id_monedaprov, @gen_dt_llegada, @gen_dt_salida, @gen_am_pordescuento, @gen_Fecha_Salida, @gen_Fecha_Llegada, @gen_am_basedescuento, @gen_cd_Consecutivo_depende, @gen_cd_Consecutivo_variablesadicionales, @gen_id_referencia_origen;
				END;
				CLOSE curGenItems;
				DEALLOCATE curGenItems;
				
				-- Execute spza_Factura_Crear inside a TRY CATCH
				SET @FacturaRespuesta = NULL;
				SET @FacturaEstado = NULL;

				BEGIN TRY
					DECLARE @ReturnCode INT;
					DECLARE @FacturaExecSqlStmt NVARCHAR(MAX);

					SET @FacturaExecSqlStmt = N'
						EXEC @ReturnCode = dbo.spza_FacturaJOB_Crear' + CHAR(13) + CHAR(10) +
							'@id_usuario = 1,' + CHAR(13) + CHAR(10) +
							'@id_sucursal = ' + ISNULL(CAST(@id_sucursal AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@id_implante = ' + ISNULL(CAST(@id_implante AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@dt_fechacont = ' + ISNULL('''' + CONVERT(VARCHAR, @FechaCont, 120) + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@dt_vence = ' + ISNULL('''' + CONVERT(VARCHAR, @FechaCont, 120) + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@cd_tercero_codigo = ' + ISNULL('''' + REPLACE(@cd_cliente, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_tercero_nombre = ' + ISNULL('''' + REPLACE(@ds_cliname, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@cd_cliente_codigo = ' + ISNULL('''' + REPLACE(@cd_cliente, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_cliente_nombre = ' + ISNULL('''' + REPLACE(@ds_cliname, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_cliente_dir = ' + ISNULL('''' + REPLACE(@ds_clidir, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_cliente_ciudad = ' + ISNULL('''' + REPLACE(@ds_clicity, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_cliente_tel = ' + ISNULL('''' + REPLACE(@ds_clitel, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_cliente_dirdesp = ' + ISNULL('''' + REPLACE(@ds_clidir, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_cliente_email = ' + ISNULL('''' + REPLACE(@ds_ClienteEmail, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_cliente_contacto = ' + ISNULL('''' + REPLACE(@ds_cliname, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_cliente_contacto_email = ' + ISNULL('''' + REPLACE(@ds_ClienteEmail, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@id_monedas_iata = ' + ISNULL(CAST(@id_monedas_iata AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@cd_vendedor = ' + ISNULL('''' + REPLACE(@cd_vendedor, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@id_tiqueteador = ' + ISNULL(CAST(@id_tiqueteador AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@bn_anexo = NULL,' + CHAR(13) + CHAR(10) +
							'@Tcambio = ' + ISNULL(CAST(@am_TasaCambio AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@am_tcambiousd = ' + ISNULL(CAST(@am_tcambiousd AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@id_tipoventa = ' + ISNULL(CAST(@id_tipoventa AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_num_resolucion = '''',' + CHAR(13) + CHAR(10) +
							'@in_num_inicial = 0,' + CHAR(13) + CHAR(10) +
							'@in_num_final = 0,' + CHAR(13) + CHAR(10) +
							'@ds_numeracion_autorizada = NULL,' + CHAR(13) + CHAR(10) +
							'@dt_fecha_resolucion = NULL,' + CHAR(13) + CHAR(10) +
							'@CodigoArchivoFisico = '''',' + CHAR(13) + CHAR(10) +
							'@ds_Observacion = ' + ISNULL('''' + REPLACE(@ds_Observaciones, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_Campo_libre1 = NULL,' + CHAR(13) + CHAR(10) +
							'@ds_Campo_libre2 = NULL,' + CHAR(13) + CHAR(10) +
							'@cd_fuente_Reemplaza = NULL,' + CHAR(13) + CHAR(10) +
							'@cd_serie_Reemplaza = NULL,' + CHAR(13) + CHAR(10) +
							'@cd_consecutivo_Reemplaza = NULL,' + CHAR(13) + CHAR(10) +
							'@ds_Actividad_Economica = NULL,' + CHAR(13) + CHAR(10) +
							'@ds_Tarifa_ICA = NULL,' + CHAR(13) + CHAR(10) +
							'@SqlStmt = ' + ISNULL('''' + REPLACE(@SqlStmt, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@AnticiposSqlStmt = NULL,' + CHAR(13) + CHAR(10) +
							'@TotalFactura = ' + ISNULL(CAST(@ValorFactura AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@TotalCupoCreditoCliente = 0,' + CHAR(13) + CHAR(10) +
							'@bl_BloqueoCupoCredito = 0,' + CHAR(13) + CHAR(10) +
							'@bl_generadaauto = 1,' + CHAR(13) + CHAR(10) +
							'@ds_CotizacionesId = NULL,' + CHAR(13) + CHAR(10) +
							'@Id_Cierre = NULL,' + CHAR(13) + CHAR(10) +
							'@cd_TipoFact = NULL,' + CHAR(13) + CHAR(10) +
							'@id_fac_remisionRelacionada = NULL,' + CHAR(13) + CHAR(10) +
							'@id_fac_facturaRelacionada = NULL,' + CHAR(13) + CHAR(10) +
							'@ds_DescripcionFac = ' + ISNULL('''' + REPLACE(@ds_descripcion, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@bl_nocont = 0,' + CHAR(13) + CHAR(10) +
							'@ProductosSqlStmt = NULL,' + CHAR(13) + CHAR(10) +
							'@cd_CF_TipoComprobante = NULL,' + CHAR(13) + CHAR(10) +
							'@id_Licitacion = ' + ISNULL(CAST(@cd_licitacion AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ValorFactura = ' + ISNULL(CAST(@ValorFactura AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@id_Especialista = NULL,' + CHAR(13) + CHAR(10) +
							'@id_tiqueteador_Facturador = NULL,' + CHAR(13) + CHAR(10) +
							'@id_TipoFormaPagoProveedor = NULL,' + CHAR(13) + CHAR(10) +
							'@id_MedioReservacion = NULL,' + CHAR(13) + CHAR(10) +
							'@bl_refacturacion = 0,' + CHAR(13) + CHAR(10) +
							'@bl_comisiona = 0,' + CHAR(13) + CHAR(10) +
							'@cd_fuente_factura = NULL,' + CHAR(13) + CHAR(10) +
							'@cd_serie_factura = NULL,' + CHAR(13) + CHAR(10) +
							'@cd_consecutivo_factura = NULL,' + CHAR(13) + CHAR(10) +
							'@id_NotasAerolinea = NULL,' + CHAR(13) + CHAR(10) +
							'@bl_interface = 0,' + CHAR(13) + CHAR(10) +
							'@id_evento = NULL,' + CHAR(13) + CHAR(10) +
							'@bl_NoEnviarFacElectronica = 0,' + CHAR(13) + CHAR(10) +
							'@bl_DescontarComisionCxP = 0,' + CHAR(13) + CHAR(10) +
							'@ds_num_resolucion_Adicional = '''',' + CHAR(13) + CHAR(10) +
							'@id_fac_facturaRefacturacion = NULL,' + CHAR(13) + CHAR(10) +
							'@bl_refacturacion_contabilizar_saldos = 0,' + CHAR(13) + CHAR(10) +
							'@ZML_VariablesXML = NULL,' + CHAR(13) + CHAR(10) +
							'@bl_FormatoResumidoFactElectro = 0,' + CHAR(13) + CHAR(10) +
							'@bl_ExigeAdjuntoFactElectro = 0,' + CHAR(13) + CHAR(10) +
							'@bl_omitir_Validar_IVA_facturacion = 0,' + CHAR(13) + CHAR(10) +
							'@ZML_AjusteIvaXML = NULL,' + CHAR(13) + CHAR(10) +
							'@ds_RespuestaJOB = @FacturaRespuesta OUTPUT;';

					
					EXEC sp_executesql @FacturaExecSqlStmt, 
						N'@FacturaRespuesta VARCHAR(MAX) OUTPUT, @ReturnCode INT OUTPUT', 
						@FacturaRespuesta = @FacturaRespuesta OUTPUT, 
						@ReturnCode = @ReturnCode OUTPUT;
					
					IF @ReturnCode = 0
					BEGIN
						SET @FacturaEstado = 0;
					END
					ELSE
					BEGIN
						SET @FacturaEstado = 1;
						SET @FacturaRespuesta = ISNULL(@FacturaRespuesta, '') + CHAR(13) + CHAR(10) + '--- DYNAMIC EXECUTION TRACE ---' + CHAR(13) + CHAR(10) + ISNULL(@FacturaExecSqlStmt, '');
					END
				END TRY
				BEGIN CATCH
					SET @FacturaEstado = 1;
					SET @FacturaRespuesta = ERROR_MESSAGE() + CHAR(13) + CHAR(10) + '--- DYNAMIC EXECUTION TRACE ---' + CHAR(13) + CHAR(10) + ISNULL(@FacturaExecSqlStmt, '');
				END CATCH
				--SET @FacturaRespuesta = @FacturaRespuesta + ' ' + @SqlStmt;
				-- Log result and clean queue using spza_GDSFacturacionAutoJOB_InsertarLog
				IF @FacturaEstado = 0
				BEGIN
					-- Success log
					EXEC dbo.spza_GDSFacturacionAutoJOB_InsertarLog
						@id_usuario = 1,
						@cd_sucursal = @cd_sucursal,
						@dt_fecha = @Fecha,
						@ds_Mensaje = @FacturaRespuesta,
						@Id_reserva = @id_reserva,
						@cd_reserva = @cd_reserva,
						@ds_archivo = @ds_archivo,
						@bl_error = 0,
						@cd_tiqueteador = @cd_tiqueteador;
				END
				ELSE
				BEGIN
					-- Error log
					EXEC dbo.spza_GDSFacturacionAutoJOB_InsertarLog
						@id_usuario = 1,
						@cd_sucursal = @cd_sucursal,
						@dt_fecha = @Fecha,
						@ds_Mensaje = @FacturaRespuesta,
						@Id_reserva = @id_reserva,
						@cd_reserva = @cd_reserva,
						@ds_archivo = @ds_archivo,
						@bl_error = 1,
						@cd_tiqueteador = @cd_tiqueteador;
				END

				FETCH NEXT FROM curInvoices INTO @ReservaFactura;
			END;

			CLOSE curInvoices;
			DEALLOCATE curInvoices;

		WaitFor Delay @Tiempo
	End

	Return
End
GO


GO

