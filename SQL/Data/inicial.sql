IF NOT EXISTS(SELECT id FROM dbo.parametros WHERE id=900)
BEGIN
	INSERT INTO dbo.Parametros(Id,Nombre,[Descripción],Tipo,Valor,Longitud,Presicion,DeUsuario,Orden,ManejarAyuda,SeccionAyuda,ListaPosibilidades,OpcionalAyuda,Ini,Pariente,OnlyRead,DescripcionAdicional,bl_noPermitirNulo,in_valorNumericoMaximo)
    SELECT Id=900,Nombre='FacAutoJOB',[Descripción]='Facturacion automatica atravez de JOB',Tipo='S',Valor='S',Longitud=0,Presicion=0,DeUsuario=1,Orden=900,ManejarAyuda=NULL,SeccionAyuda=NULL,ListaPosibilidades='S,N',OpcionalAyuda=NULL,Ini=NULL,Pariente='P20FacturacionAutomatica',OnlyRead=0,DescripcionAdicional='Si esta en "S" se Facturara automaticamente atravez de JOB',bl_noPermitirNulo=0,in_valorNumericoMaximo=0

END
GO
IF NOT EXISTS(SELECT id FROM dbo.parametros WHERE id=901)
BEGIN
	INSERT INTO dbo.Parametros(Id,Nombre,[Descripción],Tipo,Valor,Longitud,Presicion,DeUsuario,Orden,ManejarAyuda,SeccionAyuda,ListaPosibilidades,OpcionalAyuda,Ini,Pariente,OnlyRead,DescripcionAdicional,bl_noPermitirNulo,in_valorNumericoMaximo)
    SELECT Id=901,Nombre='NumMinFacAuto',[Descripción]='Segundos de espera del JOB para ejecución automática de la facturación',Tipo='N',Valor='5',Longitud=0,Presicion=0,DeUsuario=1,Orden=901,ManejarAyuda=NULL,SeccionAyuda=NULL,ListaPosibilidades=NULL,OpcionalAyuda=NULL,Ini=NULL,Pariente='P20FacturacionAutomatica',OnlyRead=0,DescripcionAdicional='indica el tiempo en segundos de espera del JOB para ejecución automática de la facturación',bl_noPermitirNulo=0,in_valorNumericoMaximo=0

END
GO
IF NOT EXISTS(SELECT id FROM dbo.parametros WHERE id=902)
BEGIN
	INSERT INTO dbo.Parametros(Id,Nombre,[Descripción],Tipo,Valor,Longitud,Presicion,DeUsuario,Orden,ManejarAyuda,SeccionAyuda,ListaPosibilidades,OpcionalAyuda,Ini,Pariente,OnlyRead,DescripcionAdicional,bl_noPermitirNulo,in_valorNumericoMaximo)
    SELECT Id=902,Nombre='SucursalFacAuto',[Descripción]='Sucursal del JOB para ejecución automática de la facturación',Tipo='S',Valor='',Longitud=0,Presicion=0,DeUsuario=1,Orden=902,ManejarAyuda=1,SeccionAyuda='SUCURSALES',ListaPosibilidades='',OpcionalAyuda='',Ini='ZeusAgencias.INI',Pariente='P20FacturacionAutomatica',OnlyRead=0,DescripcionAdicional='indica la sucursal de las reservas a consultar del JOB para ejecución automática de la facturación',bl_noPermitirNulo=0,in_valorNumericoMaximo=0

END
GO
IF NOT EXISTS(SELECT id FROM dbo.parametros WHERE id=903)
BEGIN
	INSERT INTO dbo.Parametros(Id,Nombre,[Descripción],Tipo,Valor,Longitud,Presicion,DeUsuario,Orden,ManejarAyuda,SeccionAyuda,ListaPosibilidades,OpcionalAyuda,Ini,Pariente,OnlyRead,DescripcionAdicional,bl_noPermitirNulo,in_valorNumericoMaximo)
    SELECT Id=903,Nombre='ImplanteFacAuto',[Descripción]='Implante del JOB para ejecución automática de la facturación',Tipo='S',Valor='',Longitud=0,Presicion=0,DeUsuario=1,Orden=903,ManejarAyuda=1,SeccionAyuda='IMPLANTES',ListaPosibilidades='',OpcionalAyuda='',Ini='ZeusAgencias.INI',Pariente='P20FacturacionAutomatica',OnlyRead=0,DescripcionAdicional='indica el implante de las reservas a consultar del JOB para ejecución automática de la facturación',bl_noPermitirNulo=0,in_valorNumericoMaximo=0

END
GO
IF NOT EXISTS(SELECT id FROM dbo.GestionJob WHERE ds_NombreJob='JOBFacturacionAutomatica')
BEGIN
	INSERT INTO dbo.GestionJob(ds_NombreJob,ds_Descripcion,ds_Procedimiento,ds_TiempoEspera)
	SELECT ds_NombreJob='JOBFacturacionAutomatica',ds_Descripcion='JOB de Facturacion Automatica',ds_Procedimiento='spJOBFacturacionAuto',ds_TiempoEspera=5
END