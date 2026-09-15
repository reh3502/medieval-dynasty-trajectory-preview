"""Run in UE4.27 editor; generated assets remain in the local build project."""
from pathlib import Path
import unreal as u
L=u.MaterialEditingLibrary
folder='/Game/MDTrajectory'
asset=folder+'/M_PredictedOutline'
material=u.EditorAssetLibrary.load_asset(asset) if u.EditorAssetLibrary.does_asset_exist(asset) else None
if material is None:
    material=u.AssetToolsHelpers.get_asset_tools().create_asset('M_PredictedOutline',folder,u.Material,u.MaterialFactoryNew())
else:
    L.delete_all_material_expressions(material)
material.set_editor_property('material_domain',u.MaterialDomain.MD_POST_PROCESS)
material.set_editor_property('blendable_location',u.BlendableLocation.BL_AFTER_TONEMAPPING)
custom=L.create_material_expression(material,u.MaterialExpressionCustom,400,0)
custom.set_editor_property('output_type',u.CustomMaterialOutputType.CMOT_FLOAT3)
custom.set_editor_property('code',Path(__file__).with_name('outline.hlsl').read_text())
inputs=[]
for name in ['SceneColor','CenterDepth','CenterCustomDepth','CenterStencil','StencilId','Width','Strength','OutlineColor']:
    item=u.CustomInput();item.set_editor_property('input_name',name);inputs.append(item)
custom.set_editor_property('inputs',inputs)
for i,(name,identifier) in enumerate([
    ('SceneColor',u.SceneTextureId.PPI_POST_PROCESS_INPUT0),
    ('CenterDepth',u.SceneTextureId.PPI_SCENE_DEPTH),
    ('CenterCustomDepth',u.SceneTextureId.PPI_CUSTOM_DEPTH),
    ('CenterStencil',u.SceneTextureId.PPI_CUSTOM_STENCIL)]):
    node=L.create_material_expression(material,u.MaterialExpressionSceneTexture,0,i*150)
    node.set_editor_property('scene_texture_id',identifier)
    assert L.connect_material_expressions(node,'Color',custom,name)
for i,(name,value) in enumerate([('StencilId',254.0),('Width',2.0),('Strength',1.0)]):
    node=L.create_material_expression(material,u.MaterialExpressionScalarParameter,0,700+i*150)
    node.set_editor_property('parameter_name',name);node.set_editor_property('default_value',value)
    assert L.connect_material_expressions(node,'',custom,name)
node=L.create_material_expression(material,u.MaterialExpressionVectorParameter,0,1200)
node.set_editor_property('parameter_name','OutlineColor')
node.set_editor_property('default_value',u.LinearColor(1.0,0.52,0.08,1.0))
assert L.connect_material_expressions(node,'',custom,'OutlineColor')
assert L.connect_material_property(custom,'',u.MaterialProperty.MP_EMISSIVE_COLOR)
L.recompile_material(material)
assert u.EditorAssetLibrary.save_asset(asset,False)
u.log('MDTrajectory outline material authoring finished; shader compilation and cooking still require verification.')
