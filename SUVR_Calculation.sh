#!/bin/bash

# Put all 4D-PET files in nii.gz format whose SUVR you want to find-out in one directory(Folder) and give its location below:
pet_directory=/home/pratik

# Put all T1 files (Brain Extracted) in nii.gz format one directory(Folder) and give its location below:
T1_directory=/home/pratik

# ***Important*** :: "Name of corresponding PET File and T1 File must be same."


#Output Directory
Out_Dir=/home/pratik
## Copy "Mask" Folder in the output folder.

start_time=`date +%s`

cd $pet_directory
pet_names=`ls *nii.gz`

echo "Sub ID,Hippocampus,Postcentral_Gyrus,Posterior_cingulate_cortex,Precuneus">>$Out_Dir/SUVR_Values.csv

for each_file in $pet_names
do
	echo "Calculating SUVR for" $each_file "...."	
	cd $Out_Dir
	mkdir $each_file
	cd $each_file
	## Step 1 - T1 - PET Registration
	mkdir temp
	cd temp
	mkdir 3d_vols
	mkdir 3d_vols_align
	mkdir 3d_vols_mat
	cd $Out_Dir/$each_file/temp/3d_vols
	fslsplit $pet_directory/$each_file
	for i in $(ls)
	do
		echo $i
		if [ "$i" != "MNI_Space" ]
		then
		/usr/local/fsl/bin/flirt -in $Out_Dir/$each_file/temp/3d_vols/$i -ref $T1_directory/$each_file -out $Out_Dir/$each_file/temp/3d_vols_align/$i -omat $Out_Dir/$each_file/temp/3d_vols_mat/$i.mat -bins 256 -cost mutualinfo -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 6  -interp trilinear
		fi
	done

	#echo "3D volume Alignment [Done]"

	
	fslmerge -t $Out_Dir/$each_file/temp/pet_merged $Out_Dir/$each_file/temp/3d_vols_align/vol*
	#echo "Merged aligned 3D volume [Done]"

	fslmaths $Out_Dir/$each_file/temp/pet_merged -Tmean $Out_Dir/$each_file/CoRegistered_PET
	#echo "Co Registered PET Image generated in: "$Out_Dir/$each_file

	rm -rf temp
	rm pet_merged.nii.gz
	#echo "Deleted temporary files"

	## Step 2 : Bring T1 into MNI Space
	cd $Out_Dir/$each_file/
	
	/usr/local/fsl/bin/flirt -in $T1_directory/$each_file -ref
 /usr/local/fsl/data/standard/MNI152_T1_2mm_brain -out $Out_Dir/$each_file/T1_in_MNI -omat $Out_Dir/$each_file/T1_in_MNI.mat -bins 256 -cost mutualinfo
-searchrx -180 180 -searchry -180 180 -searchrz -180 180 -dof 12  -interp trilinear

	#echo "Conversion Complete : T1 image into MNI Space"


	## Step 3 and 4 : Bringing MASK into Subject Space
	cd $Out_Dir/$each_file/
	
	convert_xfm -omat $Out_Dir/$each_file/MNI-to-sub.mat -inverse $Out_Dir/$each_file/T1_in_MNI.mat
	/usr/local/fsl/bin/flirt -in $Out_Dir/Mask/cerebellum_pons_mask_binary.nii.gz -ref $T1_directory/$each_file -out $Out_Dir/$each_file/cerebellum_pons_mask_sub_space_binary -init $Out_Dir/$each_file/MNI-to-sub.mat -applyxfm


	## Step 5
	cd $Out_Dir/$each_file/

	fslmaths $Out_Dir/$each_file/CoRegistered_PET -mul $Out_Dir/$each_file/cerebellum_pons_mask_sub_space_binary $Out_Dir/$each_file/step_5/pet_only_cerebellum_pons
	average_activity=`fslstats $Out_Dir/$each_file/pet_only_cerebellum_pons -M`
	fslmaths $Out_Dir/$each_file/CoRegistered_PET -div $average_activity $Out_Dir/$each_file/normalized_pet_by_cerebellum_and_pons.nii.gz

	## Step 6
	cd $Out_Dir/$each_file/
	
	pvc_make4d -i $Out_Dir/Mask/talairach_label_all.nii.gz -o $Out_Dir/$each_file/talairach-4DMASK.nii.gz

	/usr/local/fsl/bin/flirt -in $Out_Dir/$each_file/normalized_pet_by_cerebellum_and_pons.nii.gz -ref
 /usr/local/fsl/data/standard/MNI152_T1_2mm_brain -out $Out_Dir/$each_file/normalised_PET_in_MNI_Space -omat $Out_Dir/$each_file/normalised_PET_in_MNI_Space.mat -bins 256 -cost mutualinfo
-searchrx -180 180 -searchry -180 180 -searchrz -180 180 -dof 12  -interp trilinear

	petpvc -i $Out_Dir/$each_file/normalised_PET_in_MNI_Space -m $Out_Dir/$each_file/talairach-4DMASK.nii.gz -o $Out_Dir/$each_file/normalized_talairach_pet_pvc_image.nii.gz --pvc IY -x 7.67 -y 7.5 -z 7.5

	/usr/local/fsl/bin/flirt -in $Out_Dir/$each_file/normalized_talairach_pet_pvc_image.nii.gz -ref $T1_directory/$each_file -out $Out_Dir/$each_file/normalized_talairach_pet_pvc_sub_space.nii.gz -init $Out_Dir/$each_file/MNI-to-sub.mat -applyxfm

	## Step 7

	#Hippocampus
	fslmaths $Out_Dir/$each_file/normalized_talairach_pet_pvc_sub_space -mul $Out_Dir/Mask/hippocampus_mask_binary $Out_Dir/$each_file/only-hippocampus-pet-pvc-talairach_sub_space.nii.gz
	hippocampus_suvr=`fslstats $Out_Dir/$each_file/only-hippocampus-pet-pvc-talairach_sub_space -M`

	#Post Central
	fslmaths $Out_Dir/$each_file/normalized_talairach_pet_pvc_sub_space -mul $Out_Dir/Mask/post_central_mask_binary $Out_Dir/$each_file/only-postcentral-pet-pvc-talairach_sub_space.nii.gz
	postcentral_suvr=`fslstats $Out_Dir/$each_file/only-postcentral-pet-pvc-talairach_sub_space -M`

	#Post Cingulate
	fslmaths $Out_Dir/$each_file/normalized_talairach_pet_pvc_sub_space -mul $Out_Dir/Mask/posterior_cingulate_mask_binary $Out_Dir/$each_file/only-postcingulate-pet-pvc-talairach_sub_space.nii.gz
	postcingulate_suvr=`fslstats $Out_Dir/$each_file/only-postcingulate-pet-pvc-talairach_sub_space -M`

	
	#Pre-Cuneous
	fslmaths $Out_Dir/$each_file/normalized_talairach_pet_pvc_sub_space -mul $Out_Dir/Mask/precuneous_mask_binary $Out_Dir/$each_file/only-precuneous-pet-pvc-talairach_sub_space.nii.gz
	precuneous_suvr=`fslstats $Out_Dir/$each_file/only-precuneous-pet-pvc-talairach_sub_space -M`

	echo `echo $each_file`,`echo $hippocampus_suvr`,`echo $postcentral_suvr`,`echo $postcingulate_suvr`,`echo $precuneous_suvr`>>$Out_Dir/SUVR_Values.csv

done

echo "**** SUVR Calculation Finished*******"
echo "Open " $Out_Dir "/SUVR_Values.csv to check the results" 

	





	
	




	
