"""Author the translucent trajectory material in the existing UE4.27 project."""
from pathlib import Path
import unreal as u
L=u.MaterialEditingLibrary
folder='/Game/MDTrajectory'
asset=folder+'/M_TrajectoryThread'
m=u.EditorAssetLibrary.load_asset(asset) if u.EditorAssetLibrary.does_asset_exist(asset) else None
if m is None:
    m=u.AssetToolsHelpers.get_asset_tools().create_asset('M_TrajectoryThread',folder,u.Material,u.MaterialFactoryNew())
else:
    L.delete_all_material_expressions(m)
m.set_editor_property('blend_mode',u.BlendMode.BLEND_TRANSLUCENT)
m.set_editor_property('shading_model',u.MaterialShadingModel.MSM_UNLIT)
m.set_editor_property('two_sided',True)
m.set_editor_property('disable_depth_test',False)
m.set_editor_property('enable_responsive_aa',True)
custom=L.create_material_expression(m,u.MaterialExpressionCustom,400,0)
custom.set_editor_property('output_type',u.CustomMaterialOutputType.CMOT_FLOAT4)
custom.set_editor_property('code',Path(__file__).with_name('trajectory.hlsl').read_text())
inputs=[]
for name in ['UV','Mask','Clock','Reveal','DrawStrength','ContactPulse','Opacity']:
    item=u.CustomInput();item.set_editor_property('input_name',name);inputs.append(item)
custom.set_editor_property('inputs',inputs)
for name,cls in [('UV',u.MaterialExpressionTextureCoordinate),('Mask',u.MaterialExpressionVertexColor),('Clock',u.MaterialExpressionTime)]:
    node=L.create_material_expression(m,cls,0,0)
    assert L.connect_material_expressions(node,'',custom,name)
for name,value in [('Reveal',1.0),('DrawStrength',1.0),('ContactPulse',0.0),('Opacity',0.85)]:
    node=L.create_material_expression(m,u.MaterialExpressionScalarParameter,0,300)
    node.set_editor_property('parameter_name',name);node.set_editor_property('default_value',value)
    assert L.connect_material_expressions(node,'',custom,name)
for rgb,output in [(True,u.MaterialProperty.MP_EMISSIVE_COLOR),(False,u.MaterialProperty.MP_OPACITY)]:
    mask=L.create_material_expression(m,u.MaterialExpressionComponentMask,700,0)
    for key,value in [('r',rgb),('g',rgb),('b',rgb),('a',not rgb)]: mask.set_editor_property(key,value)
    assert L.connect_material_expressions(custom,'',mask,'')
    if rgb:
        assert L.connect_material_property(mask,'',output)
    else:
        fade=L.create_material_expression(m,u.MaterialExpressionDepthFade,900,200)
        fade.set_editor_property('fade_distance_default',1.0)
        assert L.connect_material_expressions(mask,'',fade,'Opacity')
        assert L.connect_material_property(fade,'',output)
L.recompile_material(m)
assert u.EditorAssetLibrary.save_asset(asset,False)
u.log('MDTrajectory thread material authored')
