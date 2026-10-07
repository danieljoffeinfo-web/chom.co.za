import {mkdir,cp,rm} from 'node:fs/promises';
for (const app of ['teacher','student']) {
 const target=`dist/${app}`;await rm(target,{recursive:true,force:true});await mkdir(target,{recursive:true});
 await cp(`apps/${app}`,target,{recursive:true});await cp('packages/shared',`${target}/shared`,{recursive:true});
 if(app==='teacher')await cp('apps/student',`${target}/student`,{recursive:true});
}
